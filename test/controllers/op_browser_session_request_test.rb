# frozen_string_literal: true

require "test_helper"

class OpBrowserSessionRequestTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  setup { https! }

  test "each Visa surface reports the real root owner without a retired actor" do
    [["client", ClientToken, :user_id, "PRIVATE_VISA_SERVICE_URL", :visa_app_edge_v0_token_check_path],
     ["operator", OperatorToken, :staff_id, "PRIVATE_VISA_STAFF_URL",
      :visa_org_edge_v0_token_check_path,],].each do |type, klass, owner_key, host_key, route|
      root = klass.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
      root.update!(authentication_context: "normal") if type == "operator"
      host! ENV.fetch(host_key)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: root[owner_key].to_s, resource_type: type,
        issued_at: Time.current, access_token_ttl: 60.seconds,
        session_public_id: root.device_session.public_id, oidc_jti: root.oidc_jti,
        authentication_context: "normal",
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                 issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )
      install_browser_cookie(AuthenticationCookieName.access, credential, ENV.fetch(host_key))

      writes = []
      listener =
        ->(_name, _start, _finish, _id, event) do
          writes << event.fetch(:sql) if event.fetch(:sql).match?(/\A\s*(?:INSERT|UPDATE|DELETE)\b/i)
        end
      ActiveSupport::Notifications.subscribed(listener, "sql.active_record") do
        get public_send(route), as: :json
      end

      assert_response :ok
      assert_same true, response.parsed_body.fetch("authenticated")
      assert_equal root[owner_key], response.parsed_body.fetch("id")
      assert_equal type, response.parsed_body.fetch("type")
      assert_equal root.device_session.public_id, response.parsed_body.fetch("sid")
      assert_empty writes, "browser status GET must not mint a DBSC challenge or mutate session state"
      root.revoke!
      get public_send(route), as: :json

      assert_response :unauthorized
      assert_equal({ "authenticated" => false }, response.parsed_body)
    end
  end

  test "browser refresh rotates the verified root and preserves numeric JWT subject" do
    [["client", ClientToken, :user_id, "PRIVATE_VISA_SERVICE_URL", :visa_app_edge_v0_token_refresh_path],
     ["operator", OperatorToken, :staff_id, "PRIVATE_VISA_STAFF_URL",
      :visa_org_edge_v0_token_refresh_path,],].each do |type, klass, owner_key, host_key, route|
      root = klass.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
      root.update!(authentication_context: "normal") if type == "operator"
      host! ENV.fetch(host_key)
      install_browser_cookie(AuthenticationCookieName.refresh, root.rotate_refresh_token!, ENV.fetch(host_key))

      post public_send(route), as: :json

      assert_response :ok
      assert_same true, response.parsed_body.fetch("refreshed")
      assert_predicate root.reload.rotated_at, :present?
      replacement = klass.find(root.device_session.reload.current_refresh_token_id)

      assert_not_equal root.id, replacement.id
      payload = SecurityJwtAuthAccessTokenCodec.decode(
        cookies[AuthenticationCookieName.access], host: ENV.fetch(host_key), resource_type: type,
                                                  jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )

      assert_equal root[owner_key].to_s, payload.fetch("sub")
      assert_equal root.device_session.public_id, payload.fetch("sid")
      assert_equal replacement.oidc_jti, payload.fetch("jti")
    end
  end

  test "a verified DPoP-bound browser refresh without proof refuses before rotation" do
    root = ClientToken.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
    root.update!(dpop_jkt: "required-thumbprint")
    host! ENV.fetch("PRIVATE_VISA_SERVICE_URL")
    install_browser_cookie(
      AuthenticationCookieName.refresh, root.rotate_refresh_token!,
      ENV.fetch("PRIVATE_VISA_SERVICE_URL"),
    )

    post visa_app_edge_v0_token_refresh_path, as: :json

    assert_response :unauthorized
    assert_equal "invalid_refresh_token", response.parsed_body.fetch("error_code")
    assert_nil root.reload.rotated_at
    assert_predicate root, :revoked?
  end

  test "DBSC registration does not trust a public ID with an incorrect refresh verifier" do
    root = ClientToken.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
    secret = root.rotate_refresh_token!
    host! ENV.fetch("PRIVATE_VISA_SERVICE_URL")
    install_browser_cookie(
      AuthenticationCookieName.refresh, secret.sub(/.$/, secret.end_with?("x") ? "y" : "x"),
      ENV.fetch("PRIVATE_VISA_SERVICE_URL"),
    )
    before = root.attributes

    post visa_app_edge_v0_token_dbsc_path, as: :json

    assert_response :unprocessable_content
    assert_equal before, root.reload.attributes
  end

  test "status advertises only an existing live DBSC challenge without writing at its expiry boundary" do
    root = ClientToken.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
    now = ClientToken.database_now
    host! ENV.fetch("PRIVATE_VISA_SERVICE_URL")
    payload = AuthorizationTokenClaims.build(
      resource: nil, subject: root.user_id.to_s, resource_type: "client",
      issued_at: now, access_token_ttl: 60.seconds,
      session_public_id: root.device_session.public_id, oidc_jti: root.oidc_jti,
      authentication_context: "normal",
    )
    credential = JitSecurityJwtKeyring.encode(
      payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
               issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
    )
    install_browser_cookie(AuthenticationCookieName.access, credential, ENV.fetch("PRIVATE_VISA_SERVICE_URL"))
    travel_to(now, with_usec: true) do
      [[-1, false], [0, false], [1, true]].each do |microseconds, live|
        root.update!(
          dbsc_challenge: "existing-registration-challenge",
          dbsc_challenge_issued_at: now - SecurityTokenLifetimes::DBSC_COOKIE_TTL + Rational(microseconds, 1_000_000),
        )
        before = root.attributes

        get visa_app_edge_v0_token_check_path, as: :json

        assert_response :ok
        assert_equal live, response.headers[AuthIoKeys::Headers::DBSC_REGISTRATION].present?
        assert_equal before, root.reload.attributes
      end
    end
  end

  test "DBSC registration binds an existing verified OP root using a real proof signature" do
    root = ClientToken.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
    root.update!(dbsc_challenge: "registration-challenge", dbsc_challenge_issued_at: Time.current)
    host! ENV.fetch("PRIVATE_VISA_SERVICE_URL")
    install_browser_cookie(
      AuthenticationCookieName.refresh, root.rotate_refresh_token!,
      ENV.fetch("PRIVATE_VISA_SERVICE_URL"),
    )
    key = OpenSSL::PKey::EC.generate("prime256v1")
    proof = JWT.encode(
      { "jti" => root.dbsc_challenge, "aud" => visa_app_edge_v0_token_dbsc_url, "iat" => Time.current.to_i },
      key, "ES256", { "typ" => "dbsc+jwt", "jwk" => JWT::JWK.new(key).export },
    )

    post visa_app_edge_v0_token_dbsc_path,
         headers: { AuthIoKeys::Headers::SECURE_DBSC_RESPONSE => DbscHeaderSerializer.string(proof) }, as: :json

    assert_response :created
    assert_predicate root.reload, :binding_method_dbsc?
    assert_predicate root, :dbsc_status_active?
    assert_equal root.dbsc_session_id, response.parsed_body.fetch("session_identifier")
    assert_equal root.dbsc_session_id, cookies[AuthenticationCookieName.dbsc]
    assert_nil root.dbsc_challenge
  end

  test "DBSC registration never restores binding authority to a stopped root" do
    root = ClientToken.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
    root.update!(dbsc_challenge: "stopped-registration", dbsc_challenge_issued_at: Time.current)
    secret = root.rotate_refresh_token!
    OpAuthorityStopCommitter.stop_root(
      root: root, cause: "risk", principal_public_id: root.principal_public_id,
      authority_evidence_ref: "dbsc-registration-stop-test",
    )
    before = root.reload.attributes
    host! ENV.fetch("PRIVATE_VISA_SERVICE_URL")
    install_browser_cookie(AuthenticationCookieName.refresh, secret, ENV.fetch("PRIVATE_VISA_SERVICE_URL"))

    post visa_app_edge_v0_token_dbsc_path, as: :json

    assert_response :unprocessable_content
    assert_equal before, root.reload.attributes
    assert_predicate root, :revoked?
  end

  [[-1, false], [0, true], [1, true]].each do |microseconds, allowed|
    test "browser refresh idle boundary #{microseconds} microseconds preserves the inclusive limit" do
      root = ClientToken.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
      now = ClientToken.database_now
      host! ENV.fetch("PRIVATE_VISA_SERVICE_URL")
      travel_to(now, with_usec: true) do
        install_browser_cookie(
          AuthenticationCookieName.refresh, root.rotate_refresh_token!, ENV.fetch("PRIVATE_VISA_SERVICE_URL"),
        )
        root.update!(last_used_at: now - SecurityTokenLifetimes::CLIENT_IDLE_TTL + Rational(microseconds, 1_000_000))

        post visa_app_edge_v0_token_refresh_path, as: :json

        assert_response allowed ? :ok : :unauthorized
        assert_equal allowed, root.reload.rotated_at.present?
        assert_equal !allowed, root.revoked?
      end
    end
  end

  test "browser refresh refuses missing and body transports without changing its root" do
    root = ClientToken.find(ActiveRecord::FixtureSet.identify(:one))
    secret = root.rotate_refresh_token!
    before = root.attributes
    host! ENV.fetch("PRIVATE_VISA_SERVICE_URL")

    post visa_app_edge_v0_token_refresh_path, as: :json

    assert_response :bad_request
    assert_equal "missing_refresh_token", response.parsed_body.fetch("error_code")
    post visa_app_edge_v0_token_refresh_path, params: { refresh_token: secret }, as: :json

    assert_response :bad_request
    assert_equal "invalid_refresh_transport", response.parsed_body.fetch("error_code")
    assert_equal before, root.reload.attributes
  end

  test "missing network HMAC configuration fails before browser credential rotation" do
    root = ClientToken.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
    host! ENV.fetch("PRIVATE_VISA_SERVICE_URL")
    install_browser_cookie(
      AuthenticationCookieName.refresh, root.rotate_refresh_token!, ENV.fetch("PRIVATE_VISA_SERVICE_URL"),
    )
    before = root.attributes
    current_root_id = root.device_session.current_refresh_token_id
    # This replaces the configuration adapter's value, not HMAC or rotation behavior.
    Rails.app.creds.stub(:option, nil) do
      post visa_app_edge_v0_token_refresh_path, as: :json
    end

    assert_response :internal_server_error
    assert_equal before, root.reload.attributes
    assert_equal current_root_id, root.device_session.reload.current_refresh_token_id
  end

  test "device bound DBSC refresh verifies a real signature and preserves each realm binding" do
    [[ClientToken, "PRIVATE_VISA_SERVICE_URL", :visa_app_edge_v0_token_refresh_path, :visa_app_edge_v0_token_dbsc_path,
      :user_token_binding_method_id, ClientTokenBindingMethod::DBSC, :user_token_dbsc_status_id, ClientTokenDbscStatus::ACTIVE,],
     [OperatorToken, "PRIVATE_VISA_STAFF_URL", :visa_org_edge_v0_token_refresh_path, :visa_org_edge_v0_token_dbsc_path,
      :staff_token_binding_method_id, OperatorTokenBindingMethod::DBSC,
      :staff_token_dbsc_status_id, OperatorTokenDbscStatus::ACTIVE,],].each do |configuration|
      klass, host_key, refresh_path, dbsc_path, binding_key, binding, status_key, status = configuration
      root = klass.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
      host! ENV.fetch(host_key)
      secret = root.rotate_refresh_token!
      key = OpenSSL::PKey::EC.generate("prime256v1")
      session_id = SecureRandom.uuid
      root.update!(
        binding_key => binding, status_key => status,
        :dbsc_session_id => session_id, :dbsc_public_key => JWT::JWK.new(key).export,
        :dbsc_challenge => "device-bound-refresh", :dbsc_challenge_issued_at => Time.current,
      )
      device = root.device_session
      device.bind_dbsc!(session_id: session_id)
      digest = device.reload.dbsc_session_id_digest
      install_browser_cookie(AuthenticationCookieName.refresh, secret, ENV.fetch(host_key))
      install_browser_cookie(AuthenticationCookieName.dbsc, session_id, ENV.fetch(host_key))
      audience = "https://#{ENV.fetch(host_key)}#{public_send(dbsc_path)}"
      proof = JWT.encode(
        { "jti" => root.dbsc_challenge, "aud" => audience, "iat" => Time.current.to_i },
        key, "ES256", { "typ" => "dbsc+jwt" },
      )
      count = klass.count

      post "#{public_send(refresh_path)}?ri=jp&lx=en", headers: {
        "Sec-Secure-Session-Id" => DbscHeaderSerializer.string(session_id),
        AuthIoKeys::Headers::SECURE_DBSC_RESPONSE => DbscHeaderSerializer.string(proof),
      }, as: :json

      assert_response :ok
      assert_same true, response.parsed_body.fetch("refreshed")
      assert_predicate root.reload.rotated_at, :present?
      assert_equal count + 1, klass.count
      replacement = klass.find(device.reload.current_refresh_token_id)

      assert_predicate replacement, :active_status?
      assert_equal binding, replacement[binding_key]
      assert_equal status, replacement[status_key]
      assert_equal session_id, replacement.dbsc_session_id
      assert_equal root.dbsc_public_key, replacement.dbsc_public_key
      assert_nil replacement.dbsc_challenge
      assert_nil replacement.dbsc_challenge_issued_at
      assert_equal digest, device.dbsc_session_id_digest
      assert_predicate device, :usable?
      assert_equal session_id, cookies[AuthenticationCookieName.dbsc]
      assert_not_equal secret, cookies[AuthenticationCookieName.refresh]
      assert_predicate cookies[AuthenticationCookieName.access], :present?
    end
  end

  test "device bound DBSC refresh refuses a real wrong key signature without rotating or rewriting bindings" do
    [[ClientToken, "PRIVATE_VISA_SERVICE_URL", :visa_app_edge_v0_token_refresh_path, :visa_app_edge_v0_token_dbsc_path,
      :user_token_binding_method_id, ClientTokenBindingMethod::DBSC, :user_token_dbsc_status_id, ClientTokenDbscStatus::ACTIVE,],
     [OperatorToken, "PRIVATE_VISA_STAFF_URL", :visa_org_edge_v0_token_refresh_path, :visa_org_edge_v0_token_dbsc_path,
      :staff_token_binding_method_id, OperatorTokenBindingMethod::DBSC,
      :staff_token_dbsc_status_id, OperatorTokenDbscStatus::ACTIVE,],].each do |configuration|
      klass, host_key, refresh_path, dbsc_path, binding_key, binding, status_key, status = configuration
      root = klass.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
      host! ENV.fetch(host_key)
      secret = root.rotate_refresh_token!
      key = OpenSSL::PKey::EC.generate("prime256v1")
      wrong_key = OpenSSL::PKey::EC.generate("prime256v1")
      session_id = SecureRandom.uuid
      root.update!(
        binding_key => binding, status_key => status,
        :dbsc_session_id => session_id, :dbsc_public_key => JWT::JWK.new(key).export,
        :dbsc_challenge => "wrong-device-key", :dbsc_challenge_issued_at => Time.current,
      )
      device = root.device_session
      device.bind_dbsc!(session_id: session_id)
      binding_attributes = root.attributes.slice(
        binding_key.to_s, status_key.to_s, "dbsc_session_id", "dbsc_public_key",
        "dbsc_challenge", "dbsc_challenge_issued_at",
      )
      device_binding = device.reload.attributes.slice(
        "dbsc_session_id_digest", "dbsc_public_key_thumbprint",
        "dbsc_bound_at",
      )
      install_browser_cookie(AuthenticationCookieName.refresh, secret, ENV.fetch(host_key))
      install_browser_cookie(AuthenticationCookieName.dbsc, session_id, ENV.fetch(host_key))
      proof = JWT.encode(
        { "jti" => root.dbsc_challenge,
          "aud" => "https://#{ENV.fetch(host_key)}#{public_send(dbsc_path)}",
          "iat" => Time.current.to_i, },
        wrong_key, "ES256", { "typ" => "dbsc+jwt" },
      )
      count = klass.count

      post public_send(refresh_path), headers: {
        "Sec-Secure-Session-Id" => DbscHeaderSerializer.string(session_id),
        AuthIoKeys::Headers::SECURE_DBSC_RESPONSE => DbscHeaderSerializer.string(proof),
      }, as: :json

      assert_response :unauthorized
      assert_equal "invalid_refresh_token", response.parsed_body.fetch("error_code")
      assert_nil root.reload.rotated_at
      assert_predicate root, :revoked?
      assert_not root.active_status?
      assert_equal count, klass.count
      assert_equal root.id, device.reload.current_refresh_token_id
      assert_equal binding_attributes, root.attributes.slice(*binding_attributes.keys)
      assert_equal device_binding, device.attributes.slice(*device_binding.keys)
      assert_predicate cookies[AuthenticationCookieName.refresh], :blank?
      assert_predicate cookies[AuthenticationCookieName.dbsc], :blank?
      assert_predicate cookies[AuthenticationCookieName.access], :blank?
    end
  end

  private

  def install_browser_cookie(name, value, host)
    cookies << Rack::Test::Cookie.new("#{name}=#{Rack::Utils.escape(value)}", URI.parse("https://#{host}/"))
  end
end
