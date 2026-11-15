# frozen_string_literal: true

# Owner decision 2026-11-15 (adr/access-is-a-pure-openid-provider.md, "OP session and transaction
# storage decisions"): root tokens, device sessions and grants are keyed by the Governance public
# identifier instead of the staff_id of the Access-local accounts removed in 727cdb560. Access holds
# no foreign key to Governance. Rows keyed to removed accounts have no owner; they are discarded in
# development and test before this runs, and no production database is migrated by this decision.
# A grant outlives a purged root (see OpAppGrant), so its subject has no foreign key to the root;
# the model copies it from the root at creation. The structure is reversible; discarded rows are
# not restored.
class KeyOperatorOpSessionsBySubjectPublicId < ActiveRecord::Migration[8.2]
  TABLES = %i(operator_device_sessions operator_tokens op_org_grants).freeze

  def up
    TABLES.each do |table|
      next unless select_value("SELECT EXISTS (SELECT 1 FROM #{quote_table_name(table)})")

      raise ActiveRecord::MigrationError,
            "#{table} has rows keyed to removed accounts; discard them before keying by subject_public_id"
    end

    safety_assured do
      remove_foreign_key :operator_tokens, name: "fk_operator_tokens_on_staff_id_and_device_session_id"

      rename_column :operator_device_sessions, :principal_public_id, :subject_public_id
      remove_check_constraint :operator_device_sessions, name: "chk_operator_device_sessions_principal_public_id_present"
      add_check_constraint :operator_device_sessions, "subject_public_id ~ '[^[:space:]]'", name: "chk_operator_device_sessions_subject_public_id_present"
      remove_column :operator_device_sessions, :staff_id, :bigint, null: false
      add_index :operator_device_sessions, %i(subject_public_id id), unique: true

      remove_column :operator_tokens, :staff_id, :bigint, null: false
      add_column :operator_tokens, :subject_public_id, :string, limit: 255, null: false
      add_index :operator_tokens, %i(subject_public_id last_step_up_at)
      add_index :operator_tokens, %i(subject_public_id oidc_client_id)
      add_index :operator_tokens, %i(subject_public_id root_login_established_at),
                where: "root_login_established_at IS NOT NULL",
                name: "index_operator_tokens_on_subject_root_login_established_at"
      add_foreign_key :operator_tokens, :operator_device_sessions,
                      column: %i(subject_public_id device_session_id), primary_key: %i(subject_public_id id),
                      name: "fk_operator_tokens_on_subject_and_device_session", on_delete: :restrict

      add_column :op_org_grants, :subject_public_id, :string, limit: 255, null: false
      add_index :op_org_grants, %i(subject_public_id operator_token_id)
    end
  end

  def down
    TABLES.each do |table|
      next unless select_value("SELECT EXISTS (SELECT 1 FROM #{quote_table_name(table)})")

      raise ActiveRecord::MigrationError, "#{table} has rows keyed by subject_public_id"
    end

    safety_assured do
      remove_column :op_org_grants, :subject_public_id

      remove_foreign_key :operator_tokens, name: "fk_operator_tokens_on_subject_and_device_session"
      remove_column :operator_tokens, :subject_public_id
      add_column :operator_tokens, :staff_id, :bigint, null: false
      add_index :operator_tokens, %i(staff_id last_step_up_at)
      add_index :operator_tokens, %i(staff_id oidc_client_id)
      add_index :operator_tokens, %i(staff_id root_login_established_at),
                where: "root_login_established_at IS NOT NULL",
                name: "index_operator_tokens_on_staff_id_root_login_established_at"

      remove_index :operator_device_sessions, %i(subject_public_id id)
      add_column :operator_device_sessions, :staff_id, :bigint, null: false
      add_index :operator_device_sessions, %i(staff_id id), unique: true
      remove_check_constraint :operator_device_sessions, name: "chk_operator_device_sessions_subject_public_id_present"
      add_check_constraint :operator_device_sessions, "subject_public_id ~ '[^[:space:]]'", name: "chk_operator_device_sessions_principal_public_id_present"
      rename_column :operator_device_sessions, :subject_public_id, :principal_public_id

      add_foreign_key :operator_tokens, :operator_device_sessions,
                      column: %i(staff_id device_session_id), primary_key: %i(staff_id id),
                      name: "fk_operator_tokens_on_staff_id_and_device_session_id", on_delete: :restrict
    end
  end
end
