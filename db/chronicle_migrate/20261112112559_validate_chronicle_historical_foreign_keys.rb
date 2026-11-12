# frozen_string_literal: true

class ValidateChronicleHistoricalForeignKeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  # Historical creation omitted validation; reconstruction must verify existing rows too.
  def up
    validate_foreign_key(:app_document_audits, name: "fk_rails_04199ae3cc")
    validate_foreign_key(:org_timeline_audits, name: "fk_rails_1c8eb96fbb")
    validate_foreign_key(:app_timeline_audits, name: "fk_rails_2babaf0d7d")
    validate_foreign_key(:org_preference_chronicles, name: "fk_rails_3829eb3d72")
    validate_foreign_key(:operator_chronicles, name: "fk_rails_46a8075569")
    validate_foreign_key(:org_document_audits, name: "fk_rails_46d3b866ce")
    validate_foreign_key(:com_preference_chronicles, name: "fk_rails_592279f49b")
    validate_foreign_key(:chronicle_outbox_entries, name: "fk_rails_6a19517853")
    validate_foreign_key(:client_chronicles, name: "fk_rails_829f1830de")
    validate_foreign_key(:client_chronicles, name: "fk_rails_868bedb021")
    validate_foreign_key(:app_document_audits, name: "fk_rails_a9e9b70220")
    validate_foreign_key(:app_timeline_audits, name: "fk_rails_b95cff528f")
    validate_foreign_key(:com_preference_chronicles, name: "fk_rails_c194bd8de2")
    validate_foreign_key(:app_preference_chronicles, name: "fk_rails_d693b46c45")
    validate_foreign_key(:app_preference_chronicles, name: "fk_rails_da47dd8941")
    validate_foreign_key(:org_timeline_audits, name: "fk_rails_eae8a241e3")
    validate_foreign_key(:org_document_audits, name: "fk_rails_ed52fec6a9")
    validate_foreign_key(:operator_chronicles, name: "fk_rails_f0451c267b")
    validate_foreign_key(:org_preference_chronicles, name: "fk_rails_f932dbadd7")
  end

  def down
    # Restore validation metadata atomically without changing reference or deletion contracts.
    transaction do
      restore_audit_references
      restore_preference_references
      restore_document_references
      restore_timeline_references
    end
  end

  private

  def restore_audit_references
    remove_foreign_key(:client_chronicles, name: "fk_rails_829f1830de")
    add_foreign_key(
      :client_chronicles, :client_chronicle_events, column: :event_id,
                                                    name: "fk_rails_829f1830de", validate: false,
    )
    remove_foreign_key(:client_chronicles, name: "fk_rails_868bedb021")
    add_foreign_key(
      :client_chronicles, :client_chronicle_levels, column: :level_id,
                                                    name: "fk_rails_868bedb021", validate: false,
    )
    remove_foreign_key(:operator_chronicles, name: "fk_rails_f0451c267b")
    add_foreign_key(
      :operator_chronicles, :operator_chronicle_events, column: :event_id,
                                                        name: "fk_rails_f0451c267b", validate: false,
    )
    remove_foreign_key(:operator_chronicles, name: "fk_rails_46a8075569")
    add_foreign_key(
      :operator_chronicles, :operator_chronicle_levels, column: :level_id,
                                                        name: "fk_rails_46a8075569", validate: false,
    )
    remove_foreign_key(:chronicle_outbox_entries, name: "fk_rails_6a19517853")
    add_foreign_key(
      :chronicle_outbox_entries, :chronicles, column: :chronicle_id,
                                              name: "fk_rails_6a19517853", validate: false, on_delete: :nullify,
    )
  end

  def restore_preference_references
    remove_foreign_key(:app_preference_chronicles, name: "fk_rails_d693b46c45")
    add_foreign_key(
      :app_preference_chronicles, :app_preference_chronicle_events, column: :event_id,
                                                                    name: "fk_rails_d693b46c45", validate: false,
    )
    remove_foreign_key(:app_preference_chronicles, name: "fk_rails_da47dd8941")
    add_foreign_key(
      :app_preference_chronicles, :app_preference_chronicle_levels, column: :level_id,
                                                                    name: "fk_rails_da47dd8941", validate: false,
    )
    remove_foreign_key(:org_preference_chronicles, name: "fk_rails_3829eb3d72")
    add_foreign_key(
      :org_preference_chronicles, :org_preference_chronicle_events, column: :event_id,
                                                                    name: "fk_rails_3829eb3d72", validate: false,
    )
    remove_foreign_key(:org_preference_chronicles, name: "fk_rails_f932dbadd7")
    add_foreign_key(
      :org_preference_chronicles, :org_preference_chronicle_levels, column: :level_id,
                                                                    name: "fk_rails_f932dbadd7", validate: false,
    )
    remove_foreign_key(:com_preference_chronicles, name: "fk_rails_c194bd8de2")
    add_foreign_key(
      :com_preference_chronicles, :com_preference_chronicle_events, column: :event_id,
                                                                    name: "fk_rails_c194bd8de2", validate: false,
    )
    remove_foreign_key(:com_preference_chronicles, name: "fk_rails_592279f49b")
    add_foreign_key(
      :com_preference_chronicles, :com_preference_chronicle_levels, column: :level_id,
                                                                    name: "fk_rails_592279f49b", validate: false,
    )
  end

  def restore_document_references
    remove_foreign_key(:app_document_audits, name: "fk_rails_04199ae3cc")
    add_foreign_key(
      :app_document_audits, :app_document_audit_events, column: :event_id,
                                                        name: "fk_rails_04199ae3cc", validate: false,
    )
    remove_foreign_key(:app_document_audits, name: "fk_rails_a9e9b70220")
    add_foreign_key(
      :app_document_audits, :app_document_audit_levels, column: :level_id,
                                                        name: "fk_rails_a9e9b70220", validate: false,
    )
    remove_foreign_key(:org_document_audits, name: "fk_rails_46d3b866ce")
    add_foreign_key(
      :org_document_audits, :org_document_audit_events, column: :event_id,
                                                        name: "fk_rails_46d3b866ce", validate: false,
    )
    remove_foreign_key(:org_document_audits, name: "fk_rails_ed52fec6a9")
    add_foreign_key(
      :org_document_audits, :org_document_audit_levels, column: :level_id,
                                                        name: "fk_rails_ed52fec6a9", validate: false,
    )
  end

  def restore_timeline_references
    remove_foreign_key(:app_timeline_audits, name: "fk_rails_2babaf0d7d")
    add_foreign_key(
      :app_timeline_audits, :app_timeline_audit_events, column: :event_id,
                                                        name: "fk_rails_2babaf0d7d", validate: false,
    )
    remove_foreign_key(:app_timeline_audits, name: "fk_rails_b95cff528f")
    add_foreign_key(
      :app_timeline_audits, :app_timeline_audit_levels, column: :level_id,
                                                        name: "fk_rails_b95cff528f", validate: false,
    )
    remove_foreign_key(:org_timeline_audits, name: "fk_rails_eae8a241e3")
    add_foreign_key(
      :org_timeline_audits, :org_timeline_audit_events, column: :event_id,
                                                        name: "fk_rails_eae8a241e3", validate: false,
    )
    remove_foreign_key(:org_timeline_audits, name: "fk_rails_1c8eb96fbb")
    add_foreign_key(
      :org_timeline_audits, :org_timeline_audit_levels, column: :level_id,
                                                        name: "fk_rails_1c8eb96fbb", validate: false,
    )
  end
end
