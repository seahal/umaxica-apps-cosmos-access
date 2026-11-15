# frozen_string_literal: true

# Exact localized refusal text is part of the public contract.
# rubocop:disable I18n/RailsI18n/DecorateString

require "test_helper"

class OidcCurrentDeviceLogoutTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  CASES = {
    "app" => {
      token: ClientToken,
      grant: OpAppGrant,
      hint: OpAppGrantLogoutHint,
      stop: OpAppAuthorityStop,
      participant: OpAppAuthorityStopParticipant,
      target: OpAppAuthorityStopRootTarget,
      owner: :subject_public_id,
      device: ClientDeviceSession,
      root: :client_token_id,
      kind: :user_token_kind_id,
      kind_value: ClientTokenKind::BROWSER_WEB,
      resource_type: "client",
      visa_host: :visa_service,
    },
    "org" => {
      token: OperatorToken,
      grant: OpOrgGrant,
      hint: OpOrgGrantLogoutHint,
      stop: OpOrgAuthorityStop,
      participant: OpOrgAuthorityStopParticipant,
      target: OpOrgAuthorityStopRootTarget,
      owner: :subject_public_id,
      device: OperatorDeviceSession,
      root: :operator_token_id,
      kind: :staff_token_kind_id,
      kind_value: OperatorTokenKind::BROWSER_WEB,
      resource_type: "operator",
      visa_host: :visa_staff,
    },
  }.freeze

  CASES.each do |realm, config|
    test "#{realm} authorization start hands off without revoking an existing device session" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
        oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      before = config.fetch(:stop).count
      client = OidcClientRegistry.find!("core-#{realm}-jp")
      browser.get(
        "/oauth/authorize",
        params: {
          client_id: client.client_id,
          code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
          code_challenge_method: "S256",
          nonce: "existing-device-session-nonce",
          redirect_uri: client.redirect_uris_by_realm.fetch(config.fetch(:resource_type)).first,
          response_type: "code",
          ri: "jp",
          scope: "openid profile",
          state: "existing-device-session-state",
        },
      )

      assert_equal 303, browser.response.status
      jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin).host

      assert_equal jump_host, URI.parse(browser.response.location).host
      assert_equal before, config.fetch(:stop).count
      assert_not_predicate root.reload, :revoked?
      assert_predicate root.device_session.reload, :usable?
    end

    test "#{realm} logout confirmation posts to its separate confirmation endpoint" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      [nil, "jp"].each do |region|
        host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
        browser = open_session
        browser.host!(host)
        browser.https!
        type = config.fetch(:resource_type)
        payload = AuthorizationTokenClaims.build(
          resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
          access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
          oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
        )
        credential = JitSecurityJwtKeyring.encode(
          payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                   issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
        )
        browser.cookies << Rack::Test::Cookie.new(
          "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
        )
        browser.get("/oidc/logout", params: region ? { ri: region } : {})
        if region.nil?
          assert_equal 302, browser.response.status
          redirected = URI.parse(browser.response.location)
          region = Rack::Utils.parse_nested_query(redirected.query).fetch("ri")
          browser.get(redirected.request_uri)
        end

        assert_equal 200, browser.response.status
        assert_equal "strict-origin", browser.response.headers["Referrer-Policy"]
        page = Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']")

        assert page
        props = JSON.parse(page.text).fetch("props")
        document = Nokogiri::HTML(browser.response.body)

        assert document.at_css('meta[property="csp-nonce"]'), "Visa logout page must use its Inertia document layout"
        assert_equal realm, props.fetch("chrome").fetch("surface")
        assert_equal "VISA", props.fetch("chrome").fetch("family_label")
        assert_not props.fetch("clear_history")

        assert_equal "/oidc/logout/confirmation?#{{ ri: region }.to_query}", props.fetch("form").fetch("action")
        # The confirmation answers through Jump to the RP's post-logout URI; browsers apply
        # form-action to that redirect, so every registered post-logout origin of this realm is
        # allowed here.
        form_action = browser.response.headers.fetch("Content-Security-Policy").split(";").map(&:strip)
          .find { |directive| directive.start_with?("form-action ") }.split(/\s+/).drop(1)
        post_logout_origins =
          OidcClientRegistry.client_ids.flat_map do |client_id|
            client = OidcClientRegistry.find!(client_id)
            next [] unless client.redirect_uris_by_realm.key?(config.fetch(:resource_type))

            client.post_logout_redirect_uris.map do |uri|
              parsed = URI.parse(uri)
              port = (parsed.port == parsed.default_port) ? "" : ":#{parsed.port}"
              "#{parsed.scheme}://#{parsed.host}#{port}"
            end
          end

        assert_predicate post_logout_origins, :present?
        post_logout_origins.each { |origin| assert_includes form_action, origin }
        browser.get("/oidc/logout", params: { ri: region })

        assert_equal 200, browser.response.status
        assert_equal "strict-origin", browser.response.headers["Referrer-Policy"]
      end
    end

    test "#{realm} validates hint signature issuer audience and accepts an expired hint" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      client = OidcClientRegistry.find!("core-#{realm}-jp")
      grant = config.fetch(:grant).create!(
        :authentication_epoch => 0, config.fetch(:root) => root.id, :device_session_id => root.device_session_id,
        :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
        :oidc_auth_time => 1.minute.ago, :refresh_token_expires_at => 10.minutes.from_now,
      )
      resource_type = config.fetch(:resource_type)
      config.fetch(:hint).create!(
        grant: grant,
        id_token: OidcIdTokenIssuer.call(
          resource_type:, client:, nonce: grant.oidc_nonce, issued_at: Time.current,
          expires_at: 10.minutes.from_now, issuer: OidcIssuer.for_resource_type(resource_type),
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
          subject: "#{OidcSubject.prefix_for(resource_type)}_#{root.subject_public_id}",
          sid: grant.public_id, auth_time: grant.oidc_auth_time,
        ),
      )
      client = OidcClientRegistry.find!(grant.oidc_client_id)
      foreign = OidcIdTokenIssuer.call(
        resource_type: config.fetch(:resource_type), client: client, nonce: "nonce", issuer: "https://foreign.example",
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(config.fetch(:resource_type)),
        subject: "#{OidcSubject.prefix_for(config.fetch(:resource_type))}_#{root.subject_public_id}",
        sid: grant.public_id,
      )
      invalids = [
        ["#{config.fetch(:hint).find_by!(grant_id: grant.id).id_token}x", client.client_id],
        [foreign, client.client_id],
        [config.fetch(:hint).find_by!(grant_id: grant.id).id_token, "warp-#{realm}-jp"],
      ]
      invalids.each do |token, client_id|
        host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
        browser = open_session
        browser.host!(host)
        browser.https!
        type = config.fetch(:resource_type)
        payload = AuthorizationTokenClaims.build(
          resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
          access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
          oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
        )
        credential = JitSecurityJwtKeyring.encode(
          payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                   issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
        )
        browser.cookies << Rack::Test::Cookie.new(
          "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
        )
        client = OidcClientRegistry.find!(grant.oidc_client_id)
        browser.get(
          "/oidc/logout", params: {
            id_token_hint: token,
            client_id: client_id,
            post_logout_redirect_uri: client.post_logout_redirect_uris.first,
            state: "test-state",
            ri: "jp",
            lx: "en",
          },
        )

        assert_equal 400, browser.response.status
        assert_nil browser.response.location
        assert_nil browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
        assert_not_includes browser.response.body, I18n.t("sign.shared.sign_out.completed_description", locale: :en)
        assert_not_predicate root.reload, :revoked?
        assert_predicate grant.reload, :active?
      end

      expired = OidcIdTokenIssuer.call(
        resource_type: config.fetch(:resource_type), client: client, nonce: "nonce",
        issued_at: 10.minutes.ago, expires_at: 1.minute.ago,
        issuer: OidcIssuer.for_resource_type(config.fetch(:resource_type)),
        jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(config.fetch(:resource_type)),
        subject: "#{OidcSubject.prefix_for(config.fetch(:resource_type))}_#{root.subject_public_id}",
        sid: grant.public_id,
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
        oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      client = OidcClientRegistry.find!(grant.oidc_client_id)
      browser.get(
        "/oidc/logout", params: {
          id_token_hint: expired,
          client_id: grant.oidc_client_id,
          post_logout_redirect_uri: client.post_logout_redirect_uris.first,
          state: "test-state",
          ri: "jp",
          lx: "en",
        },
      )

      assert_equal 303, browser.response.status
      pending = browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]

      assert_equal root.device_session.public_id, pending.fetch("device_session_public_id")
      assert_equal grant.public_id, pending.fetch("grant_public_id")
      assert_not_predicate root.reload, :revoked?
      assert_predicate grant.reload, :active?
    end

    test "#{realm} invalid hint displays a localized public error" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      client = OidcClientRegistry.find!("core-#{realm}-jp")
      grant = config.fetch(:grant).create!(
        :authentication_epoch => 0, config.fetch(:root) => root.id, :device_session_id => root.device_session_id,
        :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
        :oidc_auth_time => 1.minute.ago, :refresh_token_expires_at => 10.minutes.from_now,
      )
      resource_type = config.fetch(:resource_type)
      config.fetch(:hint).create!(
        grant: grant,
        id_token: OidcIdTokenIssuer.call(
          resource_type:, client:, nonce: grant.oidc_nonce, issued_at: Time.current,
          expires_at: 10.minutes.from_now, issuer: OidcIssuer.for_resource_type(resource_type),
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
          subject: "#{OidcSubject.prefix_for(resource_type)}_#{root.subject_public_id}",
          sid: grant.public_id, auth_time: grant.oidc_auth_time,
        ),
      )
      %w(en ja).each do |locale|
        host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
        browser = open_session
        browser.host!(host)
        browser.https!
        type = config.fetch(:resource_type)
        payload = AuthorizationTokenClaims.build(
          resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
          access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
          oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
        )
        credential = JitSecurityJwtKeyring.encode(
          payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                   issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
        )
        browser.cookies << Rack::Test::Cookie.new(
          "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
        )
        client = OidcClientRegistry.find!(grant.oidc_client_id)
        browser.get(
          "/oidc/logout", params: {
            id_token_hint: "invalid-hint",
            client_id: grant.oidc_client_id,
            post_logout_redirect_uri: client.post_logout_redirect_uris.first,
            state: "test-state",
            ri: "jp",
            lx: locale,
          },
        )

        assert_equal 400, browser.response.status
        assert_equal I18n.t("sign.shared.sign_out.invalid_request", locale: locale), browser.response.body
        assert_not_predicate root.reload, :revoked?
        assert_predicate grant.reload, :active?
      end
    end

    test "#{realm} invalid hint preserves the protocol error in JSON" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
        oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      browser.get(
        "/oidc/logout", params: { id_token_hint: "invalid-hint", ri: "jp" },
                        headers: { "Accept" => "application/json" },
      )

      assert_equal 400, browser.response.status
      assert_equal "no-referrer", browser.response.headers["Referrer-Policy"]
      assert_equal "invalid_request", browser.response.parsed_body.fetch("error")
      assert_equal "id_token_hint is invalid", browser.response.parsed_body.fetch("error_description")
      assert_not_predicate root.reload, :revoked?
    end

    test "#{realm} an unregistered return URI is refused even without a hint" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
        oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      browser.get(
        "/oidc/logout", params: {
          client_id: "core-#{realm}-jp", post_logout_redirect_uri: "https://attacker.example/return", ri: "jp",
        },
      )

      assert_equal 400, browser.response.status
      assert_nil browser.response.location
      assert_nil browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
      assert_not_predicate root.reload, :revoked?
    end

    test "#{realm} retry after an unknown uncommitted stop ends the same device" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
        oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      browser.get("/oidc/logout", params: { ri: "jp", lx: "en" })

      assert_equal 200, browser.response.status
      assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
      AuthenticationLogoutCurrentSession.stub(:new, ->(**) { UncommittedUnknown.new }) do
        browser.post("/oidc/logout/confirmation?ri=jp&lx=en")
      end

      assert_equal 503, browser.response.status
      assert_not_predicate root.reload, :revoked?
      assert_predicate browser.cookies[AuthenticationCookieName.access], :present?
      assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
      browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

      assert_equal 303, browser.response.status
      assert_predicate root.reload, :revoked?
    end

    test "#{realm} a different logout request cannot reuse another tab's pending return state" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
        oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      first_client = OidcClientRegistry.find!("core-#{realm}-jp")
      second_client = OidcClientRegistry.find!("warp-#{realm}-jp")
      first_uri = first_client.post_logout_redirect_uris.first
      second_uri = second_client.post_logout_redirect_uris.first

      assert_not_equal first_uri, second_uri

      browser.get(
        "/oidc/logout", params: {
          client_id: first_client.client_id,
          post_logout_redirect_uri: first_uri,
          state: "first-tab-state",
          ri: "jp",
        },
      )

      assert_equal 303, browser.response.status
      original_pending = browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY].deep_dup
      browser.get("/oidc/logout", params: { ri: "jp", lx: "en" })

      assert_equal 200, browser.response.status
      assert_equal original_pending, browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
      stop_count = config.fetch(:stop).count
      browser.get(
        "/oidc/logout", params: {
          client_id: first_client.client_id,
          post_logout_redirect_uri: first_uri,
          state: "first-tab-state",
          ri: "jp",
        },
      )

      assert_equal 200, browser.response.status
      assert_equal original_pending, browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
      browser.get(
        "/oidc/logout", params: {
          client_id: first_client.client_id,
          post_logout_redirect_uri: first_uri,
          state: "changed-state",
          ri: "jp",
        },
      )

      assert_equal 403, browser.response.status
      assert_nil browser.response.location
      assert_equal original_pending, browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
      browser.get(
        "/oidc/logout", params: {
          client_id: second_client.client_id,
          post_logout_redirect_uri: second_uri,
          state: "second-tab-state",
          ri: "jp",
        },
      )

      assert_equal 403, browser.response.status
      assert_nil browser.response.location
      assert_equal original_pending, browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
      assert_equal stop_count, config.fetch(:stop).count
      assert_not_predicate root.reload, :revoked?
      assert_predicate root.device_session.reload, :usable?
    end

    test "#{realm} a new pending request supersedes the previous completion marker" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      old_root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      new_root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: old_root.device_session.public_id,
        oidc_jti: old_root.oidc_jti, authentication_context: old_root.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      browser.get("/oidc/logout", params: { ri: "jp", lx: "en" })

      assert_equal 200, browser.response.status
      assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
      browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

      assert_equal 303, browser.response.status
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: new_root.device_session.public_id,
        oidc_jti: new_root.oidc_jti, authentication_context: new_root.strict_authentication_context_value.to_s,
      )
      cookie = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(cookie)}", URI.parse("https://#{host}/"),
      )
      browser.get("/oidc/logout", params: { ri: "jp", lx: "en" })

      assert_equal 200, browser.response.status
      assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
      travel 5.minutes
      browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

      assert_equal 422, browser.response.status
      assert_predicate new_root.reload, :currently_usable?
    end

    test "#{realm} an old confirmation after a new sign-in cannot end the new device" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      old_root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      new_root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: old_root.device_session.public_id,
        oidc_jti: old_root.oidc_jti, authentication_context: old_root.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      browser.get("/oidc/logout", params: { ri: "jp", lx: "en" })

      assert_equal 200, browser.response.status
      assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
      browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

      assert_equal 303, browser.response.status
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: new_root.device_session.public_id,
        oidc_jti: new_root.oidc_jti, authentication_context: new_root.strict_authentication_context_value.to_s,
      )
      new_cookie = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(new_cookie)}", URI.parse("https://#{host}/"),
      )
      browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

      assert_equal 422, browser.response.status
      assert_predicate new_root.reload, :currently_usable?
    end

    test "#{realm} verified hint without an OP session is forbidden in both languages" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      client = OidcClientRegistry.find!("core-#{realm}-jp")
      grant = config.fetch(:grant).create!(
        :authentication_epoch => 0, config.fetch(:root) => root.id, :device_session_id => root.device_session_id,
        :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
        :oidc_auth_time => 1.minute.ago, :refresh_token_expires_at => 10.minutes.from_now,
      )
      resource_type = config.fetch(:resource_type)
      config.fetch(:hint).create!(
        grant: grant,
        id_token: OidcIdTokenIssuer.call(
          resource_type:, client:, nonce: grant.oidc_nonce, issued_at: Time.current,
          expires_at: 10.minutes.from_now, issuer: OidcIssuer.for_resource_type(resource_type),
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
          subject: "#{OidcSubject.prefix_for(resource_type)}_#{root.subject_public_id}",
          sid: grant.public_id, auth_time: grant.oidc_auth_time,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!

      { "en" => "This action is not allowed.", "ja" => "禁止された振る舞いです" }.each do |locale, message|
        client = OidcClientRegistry.find!(grant.oidc_client_id)
        browser.get(
          "/oidc/logout", params: {
            id_token_hint: config.fetch(:hint).find_by!(grant_id: grant.id).id_token,
            client_id: grant.oidc_client_id,
            post_logout_redirect_uri: client.post_logout_redirect_uris.first,
            state: "test-state",
            ri: "jp",
            lx: locale,
          },
        )

        assert_equal 403, browser.response.status
        assert_equal message, browser.response.body
        assert_nil browser.response.location
        assert_nil browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
        assert_not_predicate root.reload, :revoked?
        assert_predicate grant.reload, :active?
      end
    end

    test "#{realm} a hint for another device of the same person cannot select its grant" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      current = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      other = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      client = OidcClientRegistry.find!("core-#{realm}-jp")
      grant = config.fetch(:grant).create!(
        :authentication_epoch => 0, config.fetch(:root) => other.id,
        :device_session_id => other.device_session_id, :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
        :oidc_auth_time => 1.minute.ago, :refresh_token_expires_at => 10.minutes.from_now,
      )
      resource_type = config.fetch(:resource_type)
      config.fetch(:hint).create!(
        grant: grant,
        id_token: OidcIdTokenIssuer.call(
          resource_type:, client:, nonce: grant.oidc_nonce, issued_at: Time.current,
          expires_at: 10.minutes.from_now, issuer: OidcIssuer.for_resource_type(resource_type),
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
          subject: "#{OidcSubject.prefix_for(resource_type)}_#{other.subject_public_id}",
          sid: grant.public_id, auth_time: grant.oidc_auth_time,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: current.device_session.public_id,
        oidc_jti: current.oidc_jti, authentication_context: current.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      client = OidcClientRegistry.find!(grant.oidc_client_id)
      browser.get(
        "/oidc/logout", params: {
          id_token_hint: config.fetch(:hint).find_by!(grant_id: grant.id).id_token,
          client_id: grant.oidc_client_id,
          post_logout_redirect_uri: client.post_logout_redirect_uris.first,
          state: "test-state",
          ri: "jp",
          lx: "en",
        },
      )

      assert_equal 403, browser.response.status
      assert_equal "This action is not allowed.", browser.response.body
      assert_nil browser.response.location
      assert_nil browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
      assert_not_predicate current.reload, :revoked?
      assert_not_predicate other.reload, :revoked?
      assert_predicate grant.reload, :active?
    end

    test "#{realm} a hint for an unrelated person cannot select its grant" do
      current_actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      other_actor = "logout-#{9_000_000 + SecureRandom.random_number(1_000_000)}"
      current = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => current_actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => current_actor,
        ),
      )
      other = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => other_actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => other_actor,
        ),
      )
      client = OidcClientRegistry.find!("core-#{realm}-jp")
      grant = config.fetch(:grant).create!(
        :authentication_epoch => 0, config.fetch(:root) => other.id,
        :device_session_id => other.device_session_id, :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
        :oidc_auth_time => 1.minute.ago, :refresh_token_expires_at => 10.minutes.from_now,
      )
      resource_type = config.fetch(:resource_type)
      config.fetch(:hint).create!(
        grant: grant,
        id_token: OidcIdTokenIssuer.call(
          resource_type:, client:, nonce: grant.oidc_nonce, issued_at: Time.current,
          expires_at: 10.minutes.from_now, issuer: OidcIssuer.for_resource_type(resource_type),
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
          subject: "#{OidcSubject.prefix_for(resource_type)}_#{other.subject_public_id}",
          sid: grant.public_id, auth_time: grant.oidc_auth_time,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: current_actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: current.device_session.public_id,
        oidc_jti: current.oidc_jti, authentication_context: current.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      client = OidcClientRegistry.find!(grant.oidc_client_id)
      browser.get(
        "/oidc/logout", params: {
          id_token_hint: config.fetch(:hint).find_by!(grant_id: grant.id).id_token,
          client_id: grant.oidc_client_id,
          post_logout_redirect_uri: client.post_logout_redirect_uris.first,
          state: "test-state",
          ri: "jp",
          lx: "en",
        },
      )

      assert_equal 403, browser.response.status
      assert_equal "This action is not allowed.", browser.response.body
      assert_nil browser.response.location
      assert_nil browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
      assert_not_predicate current.reload, :revoked?
      assert_not_predicate other.reload, :revoked?
      assert_predicate grant.reload, :active?
    end

    test "#{realm} a no-hint request without an OP session reports already signed out" do
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      before = config.fetch(:stop).count
      browser.get("/oidc/logout", params: { ri: "jp", lx: "en" })

      assert_equal 200, browser.response.status
      page = Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']")

      assert page
      assert_equal "You are already signed out.", JSON.parse(page.text).fetch("props").fetch("description")
      page = Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']")
      props = JSON.parse(page.text).fetch("props")

      assert_instance_of FalseClass, props.fetch("active")
      assert_nil props.fetch("form")
      assert_nil browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY]
      assert_equal before, config.fetch(:stop).count
    end

    test "#{realm} confirmation refuses a different current device" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      original = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => other_actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      replacement = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: original.device_session.public_id,
        oidc_jti: original.oidc_jti, authentication_context: original.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      browser.get("/oidc/logout", params: { ri: "jp", lx: "en" })

      assert_equal 200, browser.response.status
      assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: replacement.device_session.public_id,
        oidc_jti: replacement.oidc_jti, authentication_context: replacement.strict_authentication_context_value.to_s,
      )
      cookie = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(cookie)}", URI.parse("https://#{host}/"),
      )
      browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

      assert_equal 403, browser.response.status
      assert_equal "This action is not allowed.", browser.response.body
      assert_not_predicate original.reload, :revoked?
      assert_not_predicate replacement.reload, :revoked?
    end

    test "#{realm} a repeated confirmation reports already signed out and writes no second stop" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
        oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      browser.get("/oidc/logout", params: { ri: "jp", lx: "en" })

      assert_equal 200, browser.response.status
      assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
      browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

      assert_equal 303, browser.response.status
      stops = config.fetch(:stop).count
      browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

      assert_equal 200, browser.response.status
      page = Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']")

      assert page
      assert_equal "You are already signed out.", JSON.parse(page.text).fetch("props").fetch("description")
      assert_equal stops, config.fetch(:stop).count
    end

    test "#{realm} programming errors during the stop propagate" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
        oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      browser.get("/oidc/logout", params: { ri: "jp", lx: "en" })

      assert_equal 200, browser.response.status
      assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
      failure = ->(**) { raise NoMethodError, "broken stop implementation" }

      OpAuthorityStopCommitter.stub(:stop_root, failure) do
        assert_raises(NoMethodError) { browser.post("/oidc/logout/confirmation?ri=jp&lx=en") }
      end

      assert_not_predicate root.reload, :revoked?
    end

    test "#{realm} a failed precondition on an active device is forbidden" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
        oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      browser.get("/oidc/logout", params: { ri: "jp", lx: "en" })

      assert_equal 200, browser.response.status
      assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
      failure = ->(**) { raise AuthenticationLogoutCurrentSession::PreconditionFailed, "changed" }
      OpAuthorityStopCommitter.stub(:stop_root, failure) do
        browser.post("/oidc/logout/confirmation?ri=jp&lx=en")
      end

      assert_equal 403, browser.response.status
      assert_not_predicate root.reload, :revoked?
      assert_predicate browser.cookies[AuthenticationCookieName.access], :present?
    end

    test "#{realm} a failed precondition after a committed stop reports already signed out" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
        oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      browser.get("/oidc/logout", params: { ri: "jp", lx: "en" })

      assert_equal 200, browser.response.status
      assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
      original_new = AuthenticationLogoutCurrentSession.method(:new)
      factory = ->(**arguments) { CommittedPrecondition.new(original_new.call(**arguments)) }
      AuthenticationLogoutCurrentSession.stub(:new, factory) do
        browser.post("/oidc/logout/confirmation?ri=jp&lx=en")
      end

      assert_equal 200, browser.response.status
      page = Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']")

      assert page
      assert_equal "You are already signed out.", JSON.parse(page.text).fetch("props").fetch("description")
      assert_predicate root.reload, :revoked?
      assert_not browser.cookies[AuthenticationCookieName.access].present?
    end

    test "#{realm} an unreadable persisted device preserves the browser and returns unknown" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
        oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      browser.get("/oidc/logout", params: { ri: "jp", lx: "en" })

      assert_equal 200, browser.response.status
      assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
      device_class = root.device_session.class
      original_find = device_class.method(:find_by)
      stop_failed = false
      lookup =
        lambda do |**attributes|
          raise ActiveRecord::ConnectionNotEstablished, "writer unavailable" if stop_failed && attributes.key?(:id)

          original_find.call(**attributes)
        end
      failure =
        lambda do |**|
          stop_failed = true
          raise ActiveRecord::StatementInvalid, "stop failed"
        end
      device_class.stub(:find_by, lookup) do
        OpAuthorityStopCommitter.stub(:stop_root, failure) do
          browser.post("/oidc/logout/confirmation?ri=jp&lx=en")
        end
      end

      assert_equal 503, browser.response.status
      assert_nil browser.response.location
      assert_not_predicate root.reload, :revoked?
      assert_predicate browser.cookies[AuthenticationCookieName.access], :present?
    end

    test "#{realm} a stop failing before commit keeps the browser and pending request" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      client = OidcClientRegistry.find!("core-#{realm}-jp")
      grant = config.fetch(:grant).create!(
        :authentication_epoch => 0, config.fetch(:root) => root.id, :device_session_id => root.device_session_id,
        :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
        :oidc_auth_time => 1.minute.ago, :refresh_token_expires_at => 10.minutes.from_now,
      )
      resource_type = config.fetch(:resource_type)
      config.fetch(:hint).create!(
        grant: grant,
        id_token: OidcIdTokenIssuer.call(
          resource_type:, client:, nonce: grant.oidc_nonce, issued_at: Time.current,
          expires_at: 10.minutes.from_now, issuer: OidcIssuer.for_resource_type(resource_type),
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
          subject: "#{OidcSubject.prefix_for(resource_type)}_#{root.subject_public_id}",
          sid: grant.public_id, auth_time: grant.oidc_auth_time,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
        oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      browser.get("/oidc/logout", params: { ri: "jp", lx: "en" })

      assert_equal 200, browser.response.status
      assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
      failure = ->(**) { raise ActiveRecord::ConnectionNotEstablished, "stop failed before commit" }
      OpAuthorityStopCommitter.stub(:stop_root, failure) do
        browser.post("/oidc/logout/confirmation?ri=jp&lx=en")
      end

      assert_equal 500, browser.response.status
      assert_nil browser.response.location
      assert_not_predicate root.reload, :revoked?
      assert_predicate grant.reload, :active?
      assert_predicate browser.cookies[AuthenticationCookieName.access], :present?
      assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
    end

    test "#{realm} an unknown commit keeps the browser and a retry observes the committed stop" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
        oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      browser.get("/oidc/logout", params: { ri: "jp", lx: "en" })

      assert_equal 200, browser.response.status
      assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
      original_new = AuthenticationLogoutCurrentSession.method(:new)
      factory = ->(**arguments) { CommittedUnknown.new(original_new.call(**arguments)) }
      AuthenticationLogoutCurrentSession.stub(:new, factory) do
        browser.post("/oidc/logout/confirmation?ri=jp&lx=en")
      end

      assert_equal 503, browser.response.status
      assert_nil browser.response.location
      assert_predicate root.reload, :revoked?
      assert_predicate browser.cookies[AuthenticationCookieName.access], :present?
      assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
      stops = config.fetch(:stop).count
      browser.post("/oidc/logout/confirmation?ri=jp&lx=en")

      assert_equal 200, browser.response.status
      page = Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']")

      assert page
      assert_equal "You are already signed out.", JSON.parse(page.text).fetch("props").fetch("description")
      assert_equal stops, config.fetch(:stop).count
    end

    test "#{realm} a notice store failure after commit renders the signed-out page" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      client = OidcClientRegistry.find!("core-#{realm}-jp")
      grant = config.fetch(:grant).create!(
        :authentication_epoch => 0, config.fetch(:root) => root.id, :device_session_id => root.device_session_id,
        :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
        :oidc_auth_time => 1.minute.ago, :refresh_token_expires_at => 10.minutes.from_now,
      )
      resource_type = config.fetch(:resource_type)
      config.fetch(:hint).create!(
        grant: grant,
        id_token: OidcIdTokenIssuer.call(
          resource_type:, client:, nonce: grant.oidc_nonce, issued_at: Time.current,
          expires_at: 10.minutes.from_now, issuer: OidcIssuer.for_resource_type(resource_type),
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
          subject: "#{OidcSubject.prefix_for(resource_type)}_#{root.subject_public_id}",
          sid: grant.public_id, auth_time: grant.oidc_auth_time,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
        oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      browser.get("/oidc/logout", params: { ri: "jp", lx: "en" })

      assert_equal 200, browser.response.status
      assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
      Valkey::AuthState::SignOutNoticeStore.stub(:new, FailingNoticeStore.new) do
        browser.post("/oidc/logout/confirmation?ri=jp&lx=en")
      end

      assert_equal 200, browser.response.status
      page = Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']")

      assert page
      assert_equal I18n.t("sign.shared.sign_out.completed_description", locale: :en),
                   JSON.parse(page.text).fetch("props").fetch("description")
      assert_nil browser.response.location
      assert_predicate root.reload, :revoked?
      assert_predicate grant.reload, :revoked?
      assert_not browser.cookies[AuthenticationCookieName.access].present?
      assert_equal 1, config.fetch(:target).where(root_id: root.id).count
    end

    test "#{realm} a missing Jump ticket after commit renders the signed-out page" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      client = OidcClientRegistry.find!("core-#{realm}-jp")
      grant = config.fetch(:grant).create!(
        :authentication_epoch => 0, config.fetch(:root) => root.id, :device_session_id => root.device_session_id,
        :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
        :oidc_auth_time => 1.minute.ago, :refresh_token_expires_at => 10.minutes.from_now,
      )
      resource_type = config.fetch(:resource_type)
      config.fetch(:hint).create!(
        grant: grant,
        id_token: OidcIdTokenIssuer.call(
          resource_type:, client:, nonce: grant.oidc_nonce, issued_at: Time.current,
          expires_at: 10.minutes.from_now, issuer: OidcIssuer.for_resource_type(resource_type),
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
          subject: "#{OidcSubject.prefix_for(resource_type)}_#{root.subject_public_id}",
          sid: grant.public_id, auth_time: grant.oidc_auth_time,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
        oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      client = OidcClientRegistry.find!(grant.oidc_client_id)
      browser.get(
        "/oidc/logout", params: {
          id_token_hint: config.fetch(:hint).find_by!(grant_id: grant.id).id_token,
          client_id: grant.oidc_client_id,
          post_logout_redirect_uri: client.post_logout_redirect_uris.first,
          state: "test-state",
          ri: "jp",
          lx: "en",
        },
      )
      3.times do
        break unless browser.response.redirect?

        location = URI.parse(browser.response.location)
        jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host
        if location.host == jump_host
          rt = Rack::Utils.parse_nested_query(location.query.to_s).fetch("rt")
          jump_claims, = JWT.decode(rt, nil, false)
          browser.get(jump_claims.fetch("url"))
        else
          browser.get(location.to_s)
        end
      end

      assert_equal 200, browser.response.status
      JumpRtIssuer.stub(:call, nil) { browser.post("/oidc/logout/confirmation?ri=jp&lx=en") }

      assert_equal 200, browser.response.status
      page = Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']")

      assert page
      assert_equal I18n.t("sign.shared.sign_out.completed_description", locale: :en),
                   JSON.parse(page.text).fetch("props").fetch("description")
      assert_nil browser.response.location
      assert_predicate root.reload, :revoked?
      assert_predicate grant.reload, :revoked?
      assert_not browser.cookies[AuthenticationCookieName.access].present?
    end

    test "#{realm} a rejected Jump gateway after commit renders the signed-out page" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      client = OidcClientRegistry.find!("core-#{realm}-jp")
      grant = config.fetch(:grant).create!(
        :authentication_epoch => 0, config.fetch(:root) => root.id, :device_session_id => root.device_session_id,
        :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
        :oidc_auth_time => 1.minute.ago, :refresh_token_expires_at => 10.minutes.from_now,
      )
      resource_type = config.fetch(:resource_type)
      config.fetch(:hint).create!(
        grant: grant,
        id_token: OidcIdTokenIssuer.call(
          resource_type:, client:, nonce: grant.oidc_nonce, issued_at: Time.current,
          expires_at: 10.minutes.from_now, issuer: OidcIssuer.for_resource_type(resource_type),
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
          subject: "#{OidcSubject.prefix_for(resource_type)}_#{root.subject_public_id}",
          sid: grant.public_id, auth_time: grant.oidc_auth_time,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
        oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      client = OidcClientRegistry.find!(grant.oidc_client_id)
      browser.get(
        "/oidc/logout", params: {
          id_token_hint: config.fetch(:hint).find_by!(grant_id: grant.id).id_token,
          client_id: grant.oidc_client_id,
          post_logout_redirect_uri: client.post_logout_redirect_uris.first,
          state: "test-state",
          ri: "jp",
          lx: "en",
        },
      )
      3.times do
        break unless browser.response.redirect?

        location = URI.parse(browser.response.location)
        jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host
        if location.host == jump_host
          rt = Rack::Utils.parse_nested_query(location.query.to_s).fetch("rt")
          jump_claims, = JWT.decode(rt, nil, false)
          browser.get(jump_claims.fetch("url"))
        else
          browser.get(location.to_s)
        end
      end

      assert_equal 200, browser.response.status
      failed = RedirectsTargetResult.failure(kind: :external, source: :jump_rt, reason: :invalid_origin)
      RedirectsJumpGatewayUrl.stub(:call, failed) { browser.post("/oidc/logout/confirmation?ri=jp&lx=en") }

      assert_equal 200, browser.response.status
      page = Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']")

      assert page
      assert_equal I18n.t("sign.shared.sign_out.completed_description", locale: :en),
                   JSON.parse(page.text).fetch("props").fetch("description")
      assert_nil browser.response.location
      assert_predicate root.reload, :revoked?
      assert_predicate grant.reload, :revoked?
      assert_not browser.cookies[AuthenticationCookieName.access].present?
    end

    test "#{realm} programming errors after commit propagate" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      client = OidcClientRegistry.find!("core-#{realm}-jp")
      grant = config.fetch(:grant).create!(
        :authentication_epoch => 0, config.fetch(:root) => root.id, :device_session_id => root.device_session_id,
        :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
        :oidc_auth_time => 1.minute.ago, :refresh_token_expires_at => 10.minutes.from_now,
      )
      resource_type = config.fetch(:resource_type)
      config.fetch(:hint).create!(
        grant: grant,
        id_token: OidcIdTokenIssuer.call(
          resource_type:, client:, nonce: grant.oidc_nonce, issued_at: Time.current,
          expires_at: 10.minutes.from_now, issuer: OidcIssuer.for_resource_type(resource_type),
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
          subject: "#{OidcSubject.prefix_for(resource_type)}_#{root.subject_public_id}",
          sid: grant.public_id, auth_time: grant.oidc_auth_time,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
        oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      client = OidcClientRegistry.find!(grant.oidc_client_id)
      browser.get(
        "/oidc/logout", params: {
          id_token_hint: config.fetch(:hint).find_by!(grant_id: grant.id).id_token,
          client_id: grant.oidc_client_id,
          post_logout_redirect_uri: client.post_logout_redirect_uris.first,
          state: "test-state",
          ri: "jp",
          lx: "en",
        },
      )
      3.times do
        break unless browser.response.redirect?

        location = URI.parse(browser.response.location)
        jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host
        if location.host == jump_host
          rt = Rack::Utils.parse_nested_query(location.query.to_s).fetch("rt")
          jump_claims, = JWT.decode(rt, nil, false)
          browser.get(jump_claims.fetch("url"))
        else
          browser.get(location.to_s)
        end
      end
      failure = ->(**) { raise NoMethodError, "broken redirect implementation" }

      JumpRtIssuer.stub(:call, failure) do
        assert_raises(NoMethodError) { browser.post("/oidc/logout/confirmation?ri=jp&lx=en") }
      end

      assert_predicate root.reload, :revoked?
      assert_predicate grant.reload, :revoked?
    end

    test "#{realm} redirect construction failure after commit renders the signed-out page" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      client = OidcClientRegistry.find!("core-#{realm}-jp")
      grant = config.fetch(:grant).create!(
        :authentication_epoch => 0, config.fetch(:root) => root.id, :device_session_id => root.device_session_id,
        :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
        :oidc_auth_time => 1.minute.ago, :refresh_token_expires_at => 10.minutes.from_now,
      )
      resource_type = config.fetch(:resource_type)
      config.fetch(:hint).create!(
        grant: grant,
        id_token: OidcIdTokenIssuer.call(
          resource_type:, client:, nonce: grant.oidc_nonce, issued_at: Time.current,
          expires_at: 10.minutes.from_now, issuer: OidcIssuer.for_resource_type(resource_type),
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
          subject: "#{OidcSubject.prefix_for(resource_type)}_#{root.subject_public_id}",
          sid: grant.public_id, auth_time: grant.oidc_auth_time,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
        oidc_jti: root.oidc_jti, authentication_context: root.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      client = OidcClientRegistry.find!(grant.oidc_client_id)
      browser.get(
        "/oidc/logout", params: {
          id_token_hint: config.fetch(:hint).find_by!(grant_id: grant.id).id_token,
          client_id: grant.oidc_client_id,
          post_logout_redirect_uri: client.post_logout_redirect_uris.first,
          state: "test-state",
          ri: "jp",
          lx: "en",
        },
      )
      3.times do
        break unless browser.response.redirect?

        location = URI.parse(browser.response.location)
        jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host
        if location.host == jump_host
          rt = Rack::Utils.parse_nested_query(location.query.to_s).fetch("rt")
          jump_claims, = JWT.decode(rt, nil, false)
          browser.get(jump_claims.fetch("url"))
        else
          browser.get(location.to_s)
        end
      end

      assert_equal 200, browser.response.status
      # The Jump issuer reports an unavailable ticket store by returning no token.
      failure = ->(**) { }
      JumpRtIssuer.stub(:call, failure) do
        browser.post("/oidc/logout/confirmation?ri=jp&lx=en")
      end

      assert_equal 200, browser.response.status
      page = Nokogiri::HTML(browser.response.body).at_css("script[data-page='app']")

      assert page
      assert_equal I18n.t("sign.shared.sign_out.completed_description", locale: :en),
                   JSON.parse(page.text).fetch("props").fetch("description")
      assert_nil browser.response.location
      assert_predicate root.reload, :revoked?
      assert_predicate grant.reload, :revoked?
      assert config.fetch(:participant).exists?(grant_id: grant.id)
      assert_not browser.cookies[AuthenticationCookieName.access].present?
    end

    test "#{realm} confirmation stops both rotated roots and grants through the Visa OP" do
      actor = { "app" => "logout-1001", "org" => "logout-1002" }.fetch(realm)
      predecessor = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      other_root = config.fetch(:token).create!(
        :authentication_epoch => 0, config.fetch(:owner) => actor,
        config.fetch(:kind) => config.fetch(:kind_value),
        :device_session => config.fetch(:device).create!(
          :subject_public_id => actor,
        ),
      )
      predecessor.rotate_refresh_token!
      rotated = config.fetch(:token).rotate_refresh!(presented_refresh_digest: predecessor.reload.refresh_token_digest)

      assert_equal :rotated, rotated.fetch(:status)
      current = rotated.fetch(:token)

      assert_equal predecessor.device_session_id, current.device_session_id

      client = OidcClientRegistry.find!("core-#{realm}-jp")
      origin = config.fetch(:grant).create!(
        :authentication_epoch => 0, config.fetch(:root) => current.id,
        :device_session_id => current.device_session_id, :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
        :oidc_auth_time => 1.minute.ago, :refresh_token_expires_at => 10.minutes.from_now,
      )
      resource_type = config.fetch(:resource_type)
      config.fetch(:hint).create!(
        grant: origin,
        id_token: OidcIdTokenIssuer.call(
          resource_type:, client:, nonce: origin.oidc_nonce, issued_at: Time.current,
          expires_at: 10.minutes.from_now, issuer: OidcIssuer.for_resource_type(resource_type),
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
          subject: "#{OidcSubject.prefix_for(resource_type)}_#{current.subject_public_id}",
          sid: origin.public_id, auth_time: origin.oidc_auth_time,
        ),
      )
      client = OidcClientRegistry.find!("warp-#{realm}-jp")
      sibling = config.fetch(:grant).create!(
        :authentication_epoch => 0, config.fetch(:root) => current.id,
        :device_session_id => current.device_session_id, :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
        :oidc_auth_time => 1.minute.ago, :refresh_token_expires_at => 10.minutes.from_now,
      )
      resource_type = config.fetch(:resource_type)
      config.fetch(:hint).create!(
        grant: sibling,
        id_token: OidcIdTokenIssuer.call(
          resource_type:, client:, nonce: sibling.oidc_nonce, issued_at: Time.current,
          expires_at: 10.minutes.from_now, issuer: OidcIssuer.for_resource_type(resource_type),
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
          subject: "#{OidcSubject.prefix_for(resource_type)}_#{current.subject_public_id}",
          sid: sibling.public_id, auth_time: sibling.oidc_auth_time,
        ),
      )
      client = OidcClientRegistry.find!("warp-#{realm}-jp")
      other_grant = config.fetch(:grant).create!(
        :authentication_epoch => 0, config.fetch(:root) => other_root.id,
        :device_session_id => other_root.device_session_id, :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
        :oidc_auth_time => 1.minute.ago, :refresh_token_expires_at => 10.minutes.from_now,
      )
      resource_type = config.fetch(:resource_type)
      config.fetch(:hint).create!(
        grant: other_grant,
        id_token: OidcIdTokenIssuer.call(
          resource_type:, client:, nonce: other_grant.oidc_nonce, issued_at: Time.current,
          expires_at: 10.minutes.from_now, issuer: OidcIssuer.for_resource_type(resource_type),
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
          subject: "#{OidcSubject.prefix_for(resource_type)}_#{other_root.subject_public_id}",
          sid: other_grant.public_id, auth_time: other_grant.oidc_auth_time,
        ),
      )
      host = Rails.configuration.x.boot_config.fetch(:hosts).public_send(config.fetch(:visa_host)).host
      browser = open_session
      browser.host!(host)
      browser.https!
      type = config.fetch(:resource_type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: actor.to_s, resource_type: type, issued_at: Time.current,
        access_token_ttl: 60.seconds, session_public_id: current.device_session.public_id,
        oidc_jti: current.oidc_jti, authentication_context: current.strict_authentication_context_value.to_s,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      browser.cookies << Rack::Test::Cookie.new(
        "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(credential)}", URI.parse("https://#{host}/"),
      )
      browser.get("/oidc/logout", params: { ri: "jp", lx: "en" })

      assert_equal 200, browser.response.status
      assert_predicate browser.request.session[SignOidcLogout::OIDC_LOGOUT_REQUEST_SESSION_KEY], :present?
      browser.post("/oidc/logout/confirmation?ri=jp")

      assert_equal 303, browser.response.status
      [predecessor, current].each do |root|
        assert_predicate root.reload, :revoked?
        assert_equal 1, config.fetch(:target).where(root_id: root.id).count
      end
      assert_predicate current.device_session.reload, :revoked?
      assert_predicate origin.reload, :revoked?
      assert_predicate sibling.reload, :revoked?
      assert_predicate other_root.reload, :currently_usable?
      assert_predicate other_grant.reload, :active?
      assert_equal 2, config.fetch(:participant).where(grant_id: [origin.id, sibling.id]).count
    end
  end

  class UncommittedUnknown
    def call
      raise AuthenticationLogoutCurrentSession::CommitOutcomeUnknown, "commit outcome unavailable"
    end
  end

  class CommittedPrecondition
    def initialize(operation) = @operation = operation

    def call
      @operation.call
      raise AuthenticationLogoutCurrentSession::PreconditionFailed, "device changed"
    end
  end

  class CommittedUnknown
    def initialize(operation) = @operation = operation

    def call
      @operation.call
      raise AuthenticationLogoutCurrentSession::CommitOutcomeUnknown, "commit outcome unavailable"
    end
  end

  class FailingNoticeStore
    def issue!(**) = raise(Umaxica::Valkey::Unavailable, "notice storage unavailable")
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString
