# typed: false
# frozen_string_literal: true

require "test_helper"

# OidcRefreshTokenIssuer serves all three surfaces from one code path, and every
# actor-dependent step -- the usage lookup, the risk-event actor key, and the
# connection touch -- dispatches on the parent token class. The client surface is
# already pinned by Security::Invariants::RefreshTokenReuseInvariantTest; these
# tests pin the staff branch so a surface cannot silently drop out of rotation or
# out of reuse reporting.
class OidcRefreshTokenIssuerSurfaceTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(
    client_tokens client_device_sessions client_token_kinds client_token_statuses
    client_token_binding_methods client_token_dbsc_statuses operator_tokens operator_device_sessions
    operator_token_kinds operator_token_statuses operator_token_binding_methods operator_token_dbsc_statuses
  )

  test "a staff refresh token rotates and touches the staff connection" do
    token = OperatorToken.find(ActiveRecord::FixtureSet.identify(:one))
    token.update!(authentication_context: "normal")
    connection = OperatorOidcConnection.create!(
      staff_id: token.staff_id, client_id: "core-org-jp", last_used_at: 3.days.ago,
    )
    usage = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token_id: token.id, device_session_id: token.device_session_id,
      oidc_client_id: "core-org-jp", refresh_token_expires_at: 1.hour.from_now,
    )
    refresh_token = usage.issue_refresh_token!

    result = OidcRefreshTokenIssuer.call(refresh_token: refresh_token, resource_type: "operator")

    assert_predicate result, :success?
    assert_equal usage.id, result.token.id
    assert_operator connection.reload.last_used_at, :>, 1.minute.ago
  end

  test "replaying a staff refresh token is reported as reuse against the staff id" do
    token = OperatorToken.find(ActiveRecord::FixtureSet.identify(:one))
    token.update!(authentication_context: "normal")
    usage = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token_id: token.id, device_session_id: token.device_session_id,
      oidc_client_id: "core-org-jp", refresh_token_expires_at: 1.hour.from_now,
    )
    replayed = usage.issue_refresh_token!
    sibling = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token_id: token.id, device_session_id: token.device_session_id,
      oidc_client_id: "warp-org-jp", refresh_token_expires_at: 1.hour.from_now,
    )
    sibling_refresh = sibling.issue_refresh_token!

    assert_predicate OidcRefreshTokenIssuer.call(
      refresh_token: replayed,
      resource_type: "operator",
    ), :success?

    emitted = []
    SignRiskEmitter.stub(:emit, ->(name, **attrs) { emitted << [name, attrs] }) do
      result = OidcRefreshTokenIssuer.call(refresh_token: replayed, resource_type: "operator")

      assert_not result.success?
      assert_equal :refresh_token_reuse_detected, result.reason
    end

    assert_predicate usage.reload, :revoked?
    assert_predicate token.reload, :active_status?
    assert_nil sibling.reload.revoked_at
    assert_predicate OidcRefreshTokenIssuer.call(
      refresh_token: sibling_refresh, resource_type: "operator", client_id: "warp-org-jp",
    ), :success?
    assert_equal [["refresh_reuse_detected", { staff_id: token.staff_id, user_token_id: usage.public_id }]],
                 emitted
    audit =
      ChronicleRecord.connected_to(role: :writing) do
        OperatorChronicle.where(
          event_id: OperatorChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED,
          subject_id: token.staff_id.to_s,
          subject_type: "Operator",
        ).order(occurred_at: :desc).first
      end

    assert_predicate audit, :present?
    assert_equal "rp_session_revoked", audit.context.deep_stringify_keys.fetch("result")
  end

  test "unknown staff refresh credentials do not revoke either RP grant" do
    token = OperatorToken.find(ActiveRecord::FixtureSet.identify(:one))
    token.update!(authentication_context: "normal")
    grant = OpOrgGrant.create!(
      authentication_epoch: 0, operator_token_id: token.id, device_session_id: token.device_session_id,
      oidc_client_id: "core-org-jp",
      refresh_token_expires_at: 1.hour.from_now,
    )
    sibling = OpOrgGrant.create!(
      authentication_epoch: 0, operator_token_id: token.id, device_session_id: token.device_session_id,
      oidc_client_id: "warp-org-jp",
      refresh_token_expires_at: 1.hour.from_now,
    )
    current = grant.issue_refresh_token!
    sibling_refresh = sibling.issue_refresh_token!
    public_id, = OperatorToken.parse_refresh_token(current)
    forged = OperatorToken.build_refresh_token(public_id, SecureRandom.urlsafe_base64(32))
    unknown_id = PublicId.generate

    assert_not OpOrgGrant.exists?(public_id: unknown_id)
    unknown = OperatorToken.build_refresh_token(unknown_id, SecureRandom.urlsafe_base64(32))

    assert_not_predicate OidcRefreshTokenIssuer.call(refresh_token: forged, resource_type: "operator"), :success?
    assert_not_predicate OidcRefreshTokenIssuer.call(refresh_token: "not-a-refresh-token", resource_type: "operator"),
                         :success?
    assert_not_predicate OidcRefreshTokenIssuer.call(refresh_token: unknown, resource_type: "operator"), :success?
    assert_nil grant.reload.revoked_at
    assert_nil sibling.reload.revoked_at
    assert_predicate token.reload, :active_status?
    assert_predicate OidcRefreshTokenIssuer.call(
      refresh_token: current, resource_type: "operator", client_id: "core-org-jp",
    ), :success?
    assert_predicate OidcRefreshTokenIssuer.call(
      refresh_token: sibling_refresh, resource_type: "operator", client_id: "warp-org-jp",
    ), :success?
  end

  test "a client refresh token is refused after its parent Browser Session is revoked" do
    token = ClientToken.find(ActiveRecord::FixtureSet.identify(:one))
    usage = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token_id: token.id,
      device_session_id: token.device_session_id,
      oidc_client_id: "core-app-jp",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )
    refresh_token = usage.issue_refresh_token!
    refresh_digest = usage.reload.refresh_token_digest
    refresh_generation = usage.refresh_generation

    RpSessionRevoker.call(
      scope: :browser_session, record: token, cause: "browser_logout",
      authority_evidence_ref: "test",
    )
    result = OidcRefreshTokenIssuer.call(refresh_token:, resource_type: "client")

    assert_not result.success?
    assert_equal :inactive_token, result.reason
    assert_equal refresh_digest, usage.reload.refresh_token_digest
    assert_equal refresh_generation, usage.refresh_generation
  end

  test "refresh rotation locks the browser session before its RP session" do
    token = OperatorToken.find(ActiveRecord::FixtureSet.identify(:one))
    token.update!(authentication_context: "normal")
    usage = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token_id: token.id, device_session_id: token.device_session_id,
      oidc_client_id: "core-org-jp", refresh_token_expires_at: 1.hour.from_now,
    )
    refresh_token = usage.issue_refresh_token!
    lock_tables = []
    callback =
      lambda do |*, payload|
        next if payload[:cached]

        sql = payload[:sql].to_s
        next unless sql.match?(/\bFOR UPDATE\b/i)

        if sql.match?(/\b#{Regexp.escape(OperatorToken.table_name)}\b/i)
          lock_tables << :parent
        elsif sql.match?(/\b#{Regexp.escape(OpOrgGrant.table_name)}\b/i)
          lock_tables << :child
        end
      end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      result = OidcRefreshTokenIssuer.call(refresh_token:, resource_type: "operator")

      assert_predicate result, :success?
    end

    assert_equal :parent, lock_tables.first,
                 "refresh rotation must lock the parent before the RP Session"
    assert_includes lock_tables, :child
  end
end
