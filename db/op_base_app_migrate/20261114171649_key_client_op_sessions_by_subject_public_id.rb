# frozen_string_literal: true

# Owner decision 2026-11-15 (adr/access-is-a-pure-openid-provider.md, "OP session and transaction
# storage decisions"): root tokens, device sessions and grants are keyed by the Governance public
# identifier instead of the user_id of the Access-local accounts removed in 727cdb560. Access holds
# no foreign key to Governance. Rows keyed to removed accounts have no owner; they are discarded in
# development and test before this runs, and no production database is migrated by this decision.
# A grant outlives a purged root (see OpAppGrant), so its subject has no foreign key to the root;
# the model copies it from the root at creation. The structure is reversible; discarded rows are
# not restored.
class KeyClientOpSessionsBySubjectPublicId < ActiveRecord::Migration[8.2]
  TABLES = %i(client_device_sessions client_tokens op_app_grants).freeze

  def up
    TABLES.each do |table|
      next unless select_value("SELECT EXISTS (SELECT 1 FROM #{quote_table_name(table)})")

      raise ActiveRecord::MigrationError,
            "#{table} has rows keyed to removed accounts; discard them before keying by subject_public_id"
    end

    safety_assured do
      remove_foreign_key :client_tokens, name: "fk_client_tokens_on_user_id_and_device_session_id"

      rename_column :client_device_sessions, :principal_public_id, :subject_public_id
      remove_check_constraint :client_device_sessions, name: "chk_client_device_sessions_principal_public_id_present"
      add_check_constraint :client_device_sessions, "subject_public_id ~ '[^[:space:]]'", name: "chk_client_device_sessions_subject_public_id_present"
      remove_column :client_device_sessions, :user_id, :bigint, null: false
      add_index :client_device_sessions, %i(subject_public_id id), unique: true

      remove_column :client_tokens, :user_id, :bigint, null: false
      add_column :client_tokens, :subject_public_id, :string, limit: 255, null: false
      add_index :client_tokens, %i(subject_public_id last_step_up_at)
      add_index :client_tokens, %i(subject_public_id oidc_client_id)
      add_index :client_tokens, %i(subject_public_id root_login_established_at),
                where: "root_login_established_at IS NOT NULL",
                name: "index_client_tokens_on_subject_root_login_established_at"
      add_foreign_key :client_tokens, :client_device_sessions,
                      column: %i(subject_public_id device_session_id), primary_key: %i(subject_public_id id),
                      name: "fk_client_tokens_on_subject_and_device_session", on_delete: :restrict

      add_column :op_app_grants, :subject_public_id, :string, limit: 255, null: false
      add_index :op_app_grants, %i(subject_public_id client_token_id)
    end
  end

  def down
    TABLES.each do |table|
      next unless select_value("SELECT EXISTS (SELECT 1 FROM #{quote_table_name(table)})")

      raise ActiveRecord::MigrationError, "#{table} has rows keyed by subject_public_id"
    end

    safety_assured do
      remove_column :op_app_grants, :subject_public_id

      remove_foreign_key :client_tokens, name: "fk_client_tokens_on_subject_and_device_session"
      remove_column :client_tokens, :subject_public_id
      add_column :client_tokens, :user_id, :bigint, null: false
      add_index :client_tokens, %i(user_id last_step_up_at)
      add_index :client_tokens, %i(user_id oidc_client_id)
      add_index :client_tokens, %i(user_id root_login_established_at),
                where: "root_login_established_at IS NOT NULL",
                name: "index_client_tokens_on_user_id_root_login_established_at"

      remove_index :client_device_sessions, %i(subject_public_id id)
      add_column :client_device_sessions, :user_id, :bigint, null: false
      add_index :client_device_sessions, %i(user_id id), unique: true
      remove_check_constraint :client_device_sessions, name: "chk_client_device_sessions_subject_public_id_present"
      add_check_constraint :client_device_sessions, "subject_public_id ~ '[^[:space:]]'", name: "chk_client_device_sessions_principal_public_id_present"
      rename_column :client_device_sessions, :subject_public_id, :principal_public_id

      add_foreign_key :client_tokens, :client_device_sessions,
                      column: %i(user_id device_session_id), primary_key: %i(user_id id),
                      name: "fk_client_tokens_on_user_id_and_device_session_id", on_delete: :restrict
    end
  end
end
