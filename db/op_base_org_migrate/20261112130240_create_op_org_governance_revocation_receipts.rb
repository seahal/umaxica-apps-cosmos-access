# frozen_string_literal: true

class CreateOpOrgGovernanceRevocationReceipts < ActiveRecord::Migration[8.2]
  def change
    create_table(:op_org_governance_revocation_receipts, id: :uuid, primary_key: :command_id, default: nil) do |t|
      t.string(:issuer, limit: 255, null: false)
      t.binary(:command_digest, null: false)
      t.jsonb(:command, null: false)
      t.timestamptz(:committed_at, null: false)
      t.check_constraint("octet_length(command_digest) = 32", name: "op_org_governance_receipt_digest_length")
      t.check_constraint("char_length(issuer) > 0", name: "op_org_governance_receipt_issuer_present")
      t.check_constraint(<<~SQL.squish, name: "op_org_governance_receipt_command_shape")
        jsonb_typeof(command) = 'object'
        AND command ?& ARRAY['realm', 'sub', 'scope', 'actor', 'reason']
        AND command - ARRAY['realm', 'sub', 'scope', 'actor', 'reason', 'session_public_id']::text[] = '{}'::jsonb
        AND command->>'realm' = 'org'
        AND jsonb_typeof(command->'realm') = 'string'
        AND jsonb_typeof(command->'sub') = 'string'
        AND command->>'sub' ~ '\\Aopr_[A-Za-z0-9_-]{1,255}\\Z'
        AND jsonb_typeof(command->'actor') = 'string'
        AND command->>'actor' ~ '\\A(cli|opr)_[A-Za-z0-9_-]{1,255}\\Z'
        AND jsonb_typeof(command->'reason') = 'string'
        AND command->>'reason' ~ '\\A[a-z][a-z0-9_.-]{0,63}\\Z'
        AND jsonb_typeof(command->'scope') = 'string'
        AND (
          (command->>'scope' = 'all_sessions' AND NOT command ? 'session_public_id')
          OR (
            command->>'scope' = 'session'
            AND command ? 'session_public_id'
            AND jsonb_typeof(command->'session_public_id') = 'string'
            AND command->>'session_public_id' ~ '\\A[A-Za-z0-9_-]{21}\\Z'
          )
        )
        AND octet_length(command::text) <= 4096
      SQL
    end
  end
end
