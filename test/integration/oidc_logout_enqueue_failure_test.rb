# frozen_string_literal: true

require "test_helper"

class OidcLogoutEnqueueFailureTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false
  self.fixture_table_names = []

  setup do
    @root = ClientToken.create!(
      authentication_epoch: 0, subject_public_id: PublicId.generate,
      device_session: ClientDeviceSession.create!(
        subject_public_id: PublicId.generate,
      ),
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    @grant = OpAppGrant.create!(
      authentication_epoch: 0, client_token_id: @root.id, device_session_id: @root.device_session_id,
      oidc_client_id: "core-app-jp", oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, last_used_at: Time.current, refresh_token_expires_at: 1.day.from_now,
    )
    @visa_host = OidcIssuer.host_for_resource_type("client")
    payload = AuthorizationTokenClaims.build(
      resource: nil, subject: @root.subject_public_id.to_s, resource_type: "client", issued_at: Time.current,
      access_token_ttl: 60.seconds, session_public_id: @root.device_session.public_id,
      oidc_jti: @root.oidc_jti, authentication_context: AuthenticationContextValue::NORMAL_KEY,
    )
    @visa_token = JitSecurityJwtKeyring.encode(
      payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
               issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
    )
  end

  teardown do
    stop_config = OpAuthorityStopCommitter::REALMS.fetch("app")
    stop_ids = stop_config.fetch(:root_target).where(root_id: [@root&.id].compact).pluck(:stop_id) +
      stop_config.fetch(:grant_target).where(grant_id: [@grant&.id].compact).pluck(:stop_id)
    %i(participant epoch_cutoff grant_target root_target).each do |child|
      stop_config.fetch(child).where(stop_id: stop_ids).delete_all
    end
    stop_config.fetch(:stop).where(id: stop_ids).delete_all
    device_id = @root&.device_session_id
    OpAppGrant.where(id: @grant&.id).delete_all
    ClientToken.where(id: @root&.id).delete_all
    ClientDeviceSession.where(id: device_id).delete_all if device_id
  end

  { "200" => [:acknowledged, "acknowledged"],
    "204" => [:acknowledged, "acknowledged"],
    "503" => ["http_503", "pending"], }.each do |response, (outcome, expected)|
    test "confirmation commits before the job handles a #{response} response" do
      browser = open_session
      browser.host!(@visa_host)
      browser.https!
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(@visa_token)}",
        URI.parse("https://#{@visa_host}/"),
      )
      browser.post("/oidc/logout", params: { ri: "jp", lx: "en" })
      no_delivery = ->(**) { flunk("confirmation must not deliver back-channel logout") }
      OidcBackchannelLogoutClient.stub(:call, no_delivery) do
        OpOutboxDispatchJob.stub(:perform_later, nil) do
          browser.post("/oidc/logout/confirmation?ri=jp&lx=en")
        end
      end

      assert_equal 303, browser.response.status
      assert_predicate @root.reload, :revoked?
      participant = OpAppAuthorityStopParticipant.find_by!(grant_id: @grant.id)

      assert_equal OpAuthorityStopReference.participant_status_id("pending"), participant.status_id
      OidcBackchannelLogoutClient.stub(:call, outcome) { OpOutboxDispatchJob.perform_now }

      assert_equal OpAuthorityStopReference.participant_status_id(expected), participant.reload.status_id
    end
  end

  test "a failed after-commit enqueue preserves the stop and the recurring job can deliver" do
    browser = open_session
    browser.host!(@visa_host)
    browser.https!
    browser.cookies << Rack::Test::Cookie.new(
      "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(@visa_token)}", URI.parse("https://#{@visa_host}/"),
    )
    browser.post("/oidc/logout", params: { ri: "jp", lx: "en" })

    assert_equal 200, browser.response.status
    assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
    # Solid Queue enqueues through its database; an unavailable queue surfaces as a database error.
    failure = ->(*) { raise ActiveRecord::ConnectionNotEstablished, "queue unavailable" }
    no_delivery = ->(**) { flunk("confirmation must not deliver back-channel logout") }
    OidcBackchannelLogoutClient.stub(:call, no_delivery) do
      OpOutboxDispatchJob.stub(:perform_later, failure) do
        browser.post("/oidc/logout/confirmation?ri=jp&lx=en")
      end
    end

    assert_equal 303, browser.response.status
    assert_predicate @root.reload, :revoked?
    assert_predicate @grant.reload, :revoked?
    participant = OpAppAuthorityStopParticipant.find_by!(grant_id: @grant.id)

    assert_equal OpAuthorityStopReference.participant_status_id("pending"), participant.status_id

    sweep = SolidQueue::RecurringTask.from_configuration(
      "op_outbox_dispatch", class: "OpOutboxDispatchJob", queue: "default", priority: 10,
                            schedule: "every minute",
    )
    clear_enqueued_jobs
    assert_enqueued_with(job: OpOutboxDispatchJob, args: []) do
      sweep.enqueue(at: Time.current)
    end
    delivered_sids = []
    OidcBackchannelLogoutClient.stub(
      :call, lambda { |endpoint:, logout_token:|
               delivered_sids << JWT.decode(logout_token, nil, false).first.fetch("sid")
               :acknowledged
             },
    ) do
      perform_enqueued_jobs(only: OpOutboxDispatchJob)
    end

    assert_includes delivered_sids, participant.sid

    assert_equal OpAuthorityStopReference.participant_status_id("acknowledged"), participant.reload.status_id
  end
end
