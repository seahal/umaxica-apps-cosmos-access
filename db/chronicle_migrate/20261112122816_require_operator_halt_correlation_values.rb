# frozen_string_literal: true

class RequireOperatorHaltCorrelationValues < ActiveRecord::Migration[8.2]
  def change
    # SQL NULL in an indexed JSON key must not bypass the exactly-once audit identity.
    add_check_constraint(
      :operator_chronicles, <<~'SQL'.squish,
        event_id <> 18 OR (
          jsonb_typeof(context) = 'object'
          AND jsonb_typeof(context -> 'transaction_public_id') = 'string'
          AND context ->> 'transaction_public_id' IS NOT NULL
          AND length(btrim(context ->> 'transaction_public_id', ' ' || chr(9) || chr(10) || chr(11) || chr(12) || chr(13))) > 0
          AND jsonb_typeof(context -> 'halt_generation') IN ('string', 'number')
          AND context ->> 'halt_generation' IS NOT NULL
          AND (context ->> 'halt_generation') ~ '\A(0|[1-9][0-9]*)\Z'
        )
      SQL
      name: "chk_operator_chronicles_halt_correlation_values", validate: false,
    )
  end
end
