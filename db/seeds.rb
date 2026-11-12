# typed: false
# frozen_string_literal: true

# Reference data (lookup / status tables) is normally owned by migrations, which insert the fixed
# rows with `INSERT ... ON CONFLICT DO NOTHING` (see adr/reference-table-discipline.md). This file
# also replays fixed reference catalogs after a schema-only load, because migration markers
# suppress the original data inserts. The remaining content is development/test sample data.

# A SQL structure load records the migration version without its reference rows.
# Reuse the migration's fixed catalog on the Ticket writer after a schema-only load.
require Rails.root.join("db/op_base_app_migrate/20261006160000_seed_app_sign_flow_reference_data").to_s
require Rails.root.join("db/op_base_org_migrate/20261006160002_seed_org_sign_flow_reference_data").to_s
SeedAppSignFlowReferenceData.seed_into(
  OpBaseAppRecord.lease_connection,
  tables: %i(client_sign_in_flow_states client_sign_up_flow_statuses client_sign_up_flow_cleanup_statuses),
)
SeedOrgSignFlowReferenceData.seed_into(
  OpBaseOrgRecord.lease_connection,
  tables: %i(operator_sign_in_flow_states operator_sign_up_flow_statuses),
)

[
  ClientTokenKind, ClientTokenStatus, ClientTokenBindingMethod, ClientTokenDbscStatus,
  OperatorTokenKind, OperatorTokenStatus, OperatorTokenBindingMethod, OperatorTokenDbscStatus,
  ClientStepUpEvidenceState, OperatorStepUpEvidenceState,
  ClientChronicleEvent, ClientChronicleLevel, OperatorChronicleEvent, OperatorChronicleLevel,
  AppPreferenceChronicleEvent, AppPreferenceChronicleLevel,
  OrgPreferenceChronicleEvent, OrgPreferenceChronicleLevel,
  ComPreferenceChronicleEvent, ComPreferenceChronicleLevel,
].each do |model|
  connection = model.lease_connection
  table = connection.quote_table_name(model.table_name)
  model::DEFAULTS.each do |id|
    connection.execute("INSERT INTO #{table} (id) VALUES (#{connection.quote(id)}) ON CONFLICT (id) DO NOTHING")
  end
end

require Rails.root.join(
  "db/op_base_app_migrate/20261006140000_normalize_client_session_limit_resolution_transactions",
).to_s
require Rails.root.join(
  "db/op_base_org_migrate/20261006140002_create_operator_session_limit_resolution_transactions",
).to_s
[
  [OpBaseAppRecord, :client_session_limit_resolution_states, NormalizeClientSessionLimitResolutionTransactions::STATE_IDS],
  [OpBaseOrgRecord, :operator_session_limit_resolution_states, CreateOperatorSessionLimitResolutionTransactions::STATE_IDS],
].each do |record_class, table, ids|
  connection = record_class.lease_connection
  quoted_table = connection.quote_table_name(table)
  ids.each do |id|
    connection.execute(
      "INSERT INTO #{quoted_table} (id, created_at, updated_at) " \
      "VALUES (#{connection.quote(id)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) ON CONFLICT (id) DO NOTHING",
    )
  end
end

require Rails.root.join("db/op_base_app_migrate/20261025120000_create_op_authority_stops_op_base_app").to_s
require Rails.root.join("db/op_base_org_migrate/20261025120000_create_op_authority_stops_op_base_org").to_s
[
  [OpBaseAppRecord, "app", CreateOpAuthorityStopsOpBaseApp],
  [OpBaseOrgRecord, "org", CreateOpAuthorityStopsOpBaseOrg],
].each do |record_class, realm, catalog|
  connection = record_class.lease_connection
  reference_sets = {
    causes: catalog::CAUSES, scopes: catalog::SCOPES, participant_statuses: catalog::PARTICIPANT_STATUSES,
  }
  reference_sets.each do |suffix, ids|
    table = connection.quote_table_name("op_#{realm}_authority_stop_#{suffix}")
    ids.each_key do |id|
      connection.execute("INSERT INTO #{table} (id) VALUES (#{connection.quote(id)}) ON CONFLICT (id) DO NOTHING")
    end
  end
end

return if Rails.env.production?

# Occurrence reference rows are owned by the occurrence database, not primary.
# A structure.sql load marks data migrations as applied without replaying their
# INSERTs, so reproduce the current JWT anomaly catalog through the same
# idempotent migration writer on the correct writer connection. During the
# pre-migration bootstrap both tables are absent and this section is skipped;
# a partially-created occurrence schema fails loudly instead of reporting a
# successful but incomplete seed.
occurrence_connection = OccurrenceRecord.lease_connection
occurrence_tables = %w(jwt_occurrence_statuses jwt_occurrences)
occurrence_table_presence =
  occurrence_tables.map do |table_name|
    occurrence_connection.data_source_exists?(table_name)
  end

if occurrence_table_presence.any?
  require Rails.root.join(
    "db/occurrences_migrate/20260918150000_insert_current_jwt_anomaly_reference_data",
  ).to_s
  InsertCurrentJwtAnomalyReferenceData.new.seed_into(occurrence_connection)
end

# `fqdn_available_*` carries the same `:availability` polarity, so an unwritten flag closes the
# FQDN: a fresh primary database answers every request with 503 `fqdn_unavailable` before routing.
# Every slot the router serves is opened here so a freshly seeded development environment serves the
# hosts its own routes declare. Production is untouched (this file returns above) -- switching a
# public FQDN on stays an explicit operator decision made through the Flipper UI.
FqdnAvailabilityRegistry.flag_names.each { |feature_name| Flipper.enable(feature_name) }
