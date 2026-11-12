# typed: false
# frozen_string_literal: true

# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"
# require "helpers/global_test_support"

module Security
  module Invariants
    class RefreshTokenReuseInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = %w(client_tokens client_device_sessions)

      # This test pins properties that were reviewed as "No issue found".
      # Update SECURITY_INVARIANTS.md before intentionally changing them.

      test "refresh token reuse revokes only the compromised token family" do
        original = ClientToken.create!(
          authentication_epoch: 0,
          user_id: 1001, device_session: ClientDeviceSession.create!(
            user_id: 1001, principal_public_id: "refresh-principal",
          ),
          discard_at: 1.day.from_now,
          purge_eligible_at: 2.days.from_now,
        )
        reused_refresh = original.rotate_refresh_token!
        rotated = AuthRefreshTokenIssuer.call(resource_type: "client", refresh_token: reused_refresh).fetch(:token)

        other_family = ClientToken.create!(
          authentication_epoch: 0,
          user_id: 1001, device_session: ClientDeviceSession.create!(
            user_id: 1001, principal_public_id: "refresh-principal",
          ),
          discard_at: 1.day.from_now,
          purge_eligible_at: 2.days.from_now,
        )
        other_family.rotate_refresh_token!

        result = AuthRefreshTokenIssuer.call(resource_type: "client", refresh_token: reused_refresh)

        assert_not result.success?
        assert_equal :refresh_token_reuse_detected, result.reason

        assert_operator original.reload.discard_at, :<=, Time.current
        assert_operator rotated.reload.discard_at, :<=, Time.current
        assert_not other_family.reload.revoked?,
                   "Reuse detection must not be confused with ordinary logout or revoke unrelated families"
      end

      # The two tests above cover AuthRefreshTokenIssuer, the browser-session path.
      # OAuth-issued refresh tokens rotate through OidcRefreshTokenIssuer, which was
      # not covered here and had no reuse detection at all: a replayed token simply
      # returned :invalid_digest and the evidence stored in
      # previous_refresh_token_digest was never read.
      test "oidc refresh token reuse revokes the usage and reports it" do
        root_token = ClientToken.create!(
          authentication_epoch: 0,
          user_id: 1001, device_session: ClientDeviceSession.create!(
            user_id: 1001, principal_public_id: "refresh-principal",
          ),
          discard_at: 1.day.from_now,
          purge_eligible_at: 2.days.from_now,
        )
        usage = OpAppGrant.create!(
          authentication_epoch: 0,
          client_token_id: root_token.id, oidc_client_id: "core-app-jp", refresh_token_expires_at: 1.hour.from_now,
        )
        reused_refresh = usage.issue_refresh_token!

        rotation = OidcRefreshTokenIssuer.call(refresh_token: reused_refresh, resource_type: "client")

        assert_predicate rotation, :success?, "The first redemption must rotate normally."

        replay = OidcRefreshTokenIssuer.call(refresh_token: reused_refresh, resource_type: "client")

        assert_not replay.success?
        assert_equal :refresh_token_reuse_detected, replay.reason,
                     "Replaying an already-rotated OAuth refresh token is compromise evidence, " \
                     "not an ordinary digest mismatch."
        assert_predicate usage.reload, :revoked?,
                         "Reuse must revoke the usage so neither the client nor the attacker can continue."
      end

      test "oidc refresh token rotation still succeeds for the current token" do
        root_token = ClientToken.create!(
          authentication_epoch: 0,
          user_id: 1001, device_session: ClientDeviceSession.create!(
            user_id: 1001, principal_public_id: "refresh-principal",
          ),
          discard_at: 1.day.from_now,
          purge_eligible_at: 2.days.from_now,
        )
        usage = OpAppGrant.create!(
          authentication_epoch: 0,
          client_token_id: root_token.id, oidc_client_id: "core-app-jp", refresh_token_expires_at: 1.hour.from_now,
        )
        first_refresh = usage.issue_refresh_token!

        first_rotation = OidcRefreshTokenIssuer.call(refresh_token: first_refresh, resource_type: "client")

        assert_predicate first_rotation, :success?
        second_rotation = OidcRefreshTokenIssuer.call(
          refresh_token: first_rotation.refresh_token,
          resource_type: "client",
        )

        assert_predicate second_rotation, :success?,
                         "Reuse detection must not break the legitimate rotation chain."
        assert_not usage.reload.revoked?
      end

      test "ordinary current session revoke does not revoke the whole family" do
        current = ClientToken.create!(
          authentication_epoch: 0,
          user_id: 1001, device_session: ClientDeviceSession.create!(
            user_id: 1001, principal_public_id: "refresh-principal",
          ),
          discard_at: 1.day.from_now,
          purge_eligible_at: 2.days.from_now,
        )
        refresh = current.rotate_refresh_token!
        sibling = AuthRefreshTokenIssuer.call(resource_type: "client", refresh_token: refresh).fetch(:token)

        current.revoke!

        assert_predicate current.reload, :revoked?
        assert_not sibling.reload.revoked?,
                   "Ordinary logout/current-session revoke must not revoke the entire refresh family"
      end
    end
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString
