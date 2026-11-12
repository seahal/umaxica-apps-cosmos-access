# typed: false
# frozen_string_literal: true

require "test_helper"

class RefreshTokenReuseActivityRecorderTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(
    client_tokens client_device_sessions client_token_kinds client_token_statuses
    client_token_binding_methods client_token_dbsc_statuses operator_tokens operator_device_sessions
    operator_token_kinds operator_token_statuses operator_token_binding_methods operator_token_dbsc_statuses
    client_chronicle_events client_chronicle_levels operator_chronicle_events operator_chronicle_levels
  )

  %i(app org).each do |surface|
    test "#{surface} refresh reuse writes only non-secret family metadata" do
      token = create_token(surface)
      raw_refresh_token = token.rotate_refresh_token!

      assert RefreshTokenReuseActivityRecorder.call(token: token, result: "token_family_revoked")

      event_model = (surface == :org) ? OperatorChronicle : ClientChronicle
      event_id = (surface == :org) ? OperatorChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED : ClientChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED
      record =
        ChronicleRecord.connected_to(role: :writing) do
          event_model.where(
            event_id: event_id,
            subject_id: activity_subject_id(token),
          ).order(occurred_at: :desc).first
        end

      assert_predicate record, :present?
      context = record.context.deep_stringify_keys

      assert_equal %w(generation result surface token_family_id), context.keys.sort
      assert_equal surface.to_s, context.fetch("surface")
      assert_equal "token_family_revoked", context.fetch("result")
      assert_not_includes context.values.join(" "), raw_refresh_token
      assert_not_includes context.values.join(" "), token.refresh_token_digest.to_s
    end
  end

  private

  def create_token(surface)
    case surface
    when :app
      ClientToken.find(ActiveRecord::FixtureSet.identify(:one))
    when :org
      OperatorToken.find(ActiveRecord::FixtureSet.identify(:one))
    end
  end

  def activity_subject_id(token)
    return token.user_id if token.respond_to?(:user_id)

    token.staff_id
  end
end
