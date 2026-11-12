# frozen_string_literal: true

class BackfillClientStepUpEvidenceStates < ActiveRecord::Migration[8.2]
  def up
    mixed_token_flags = select_value(<<~SQL.squish)
      SELECT EXISTS (
        SELECT 1 FROM client_tokens
        WHERE (last_step_up_user_verified IS NULL) <> (last_step_up_full_reauthentication IS NULL)
      )
    SQL
    invalid_ceremony_flags = select_value(<<~SQL.squish)
      SELECT EXISTS (
        SELECT 1 FROM client_step_up_ceremony_transactions
        WHERE (status = 'pending' AND user_verified IS NOT NULL)
           OR (status IN ('verified', 'consumed') AND user_verified IS NULL)
      )
    SQL
    if mixed_token_flags || invalid_ceremony_flags
      raise ActiveRecord::MigrationError, "step-up evidence is inconsistent; classify it before migration"
    end

    # Owner-approved representation change: retain actual false/true evidence, never infer proof.
    safety_assured do
      execute(<<~SQL.squish)
        UPDATE client_tokens
        SET evidence_state_id = CASE WHEN last_step_up_user_verified IS NULL THEN 10 ELSE 20 END,
            last_step_up_user_verified = COALESCE(last_step_up_user_verified, false),
            last_step_up_full_reauthentication = COALESCE(last_step_up_full_reauthentication, false)
      SQL
      execute(<<~SQL.squish)
        UPDATE client_step_up_ceremony_transactions
        SET evidence_state_id = CASE WHEN user_verified IS NULL THEN 10 ELSE 20 END,
            user_verified = COALESCE(user_verified, false)
      SQL
    end
  end

  def down
    safety_assured do
      execute(<<~SQL.squish)
        UPDATE client_tokens
        SET last_step_up_user_verified = NULL, last_step_up_full_reauthentication = NULL
        WHERE evidence_state_id = 10
      SQL
      execute(<<~SQL.squish)
        UPDATE client_step_up_ceremony_transactions SET user_verified = NULL WHERE evidence_state_id = 10
      SQL
    end
  end
end
