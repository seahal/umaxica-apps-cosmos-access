# frozen_string_literal: true

require "test_helper"

class VisaAuthorizationStartJwksConnection
  StreamOptions = Struct.new(:on_data)
  StreamRequest = Struct.new(:options)
  Response =
    Struct.new(:success) do
      public

      def success? = success
    end

  public

  def initialize(document)
    @document = document
  end

  def get(_uri)
    request = StreamRequest.new(StreamOptions.new)
    yield request
    request.options.on_data.call(@document, @document.bytesize, nil)
    Response.new(true)
  end
end

class VisaAuthorizationStartBoundaryTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "Base App and Org ID Token starts fail closed without transaction-backed issuance" do
    [
      ["PUBLIC_VISA_SERVICE_URL", "base-app-ww", "client", ClientOidcAuthorizationTransaction],
      ["PUBLIC_VISA_STAFF_URL", "base-org-ww", "operator", OperatorOidcAuthorizationTransaction],
    ].each do |visa_host_env, client_id, resource_type, transaction_class|
      host! ENV.fetch(visa_host_env)
      https!
      client = OidcClientRegistry.find!(client_id)
      before = transaction_class.count
      parameters = {
        response_type: "id_token",
        client_id: client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch(resource_type).first,
        scope: "openid profile",
        state: "front-channel-unavailable-state",
        nonce: "front-channel-unavailable-nonce",
        ri: "jp",
      }

      get "/oauth/authorize", params: parameters

      assert_equal 503, response.status, "#{client_id} #{response.parsed_body.inspect}"
      assert_equal "temporarily_unavailable", response.parsed_body.fetch("error")
      assert_equal "Base front-channel ID Token issuance is unavailable", response.parsed_body.fetch(
        "error_description",
      )
      assert_nil response.location
      assert_equal before, transaction_class.count
      assert_equal "no-referrer", response.headers["Referrer-Policy"]
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
    end
  end

  test "Base App and Org requests fail closed when current Governance authority cannot be checked" do
    [
      ["PUBLIC_VISA_SERVICE_URL", "base-app-ww", "client", ClientOidcAuthorizationTransaction],
      ["PUBLIC_VISA_STAFF_URL", "base-org-ww", "operator", OperatorOidcAuthorizationTransaction],
    ].each do |visa_host_env, client_id, resource_type, transaction_class|
      host! ENV.fetch(visa_host_env)
      https!
      client = OidcClientRegistry.find!(client_id)
      before = transaction_class.count
      parameters = {
        response_type: "id_token",
        client_id: client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch(resource_type).first,
        scope: "openid profile",
        state: "authority-unavailable-state",
        nonce: "authority-unavailable-nonce",
        ri: "jp",
      }

      OpBrowserSessionResolver.stub(:call, ->(*) { raise GovernanceLookupUnavailableError }) do
        get "/oauth/authorize", params: parameters
      end

      assert_equal 503, response.status
      assert_equal "temporarily_unavailable", response.parsed_body.fetch("error")
      assert_equal "Sign-in authority is unavailable", response.parsed_body.fetch("error_description")
      assert_nil response.location
      assert_equal before, transaction_class.count
      assert_equal "no-referrer", response.headers["Referrer-Policy"]
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
    end
  end

  test "Base App and Org ID Token requests through Jump remain unavailable without transaction issuance" do
    [
      ["app", "PUBLIC_VISA_SERVICE_URL", "base-app-ww", "client",
       ClientOidcAuthorizationTransaction, ClientAuthAdmissionBinding, "BASE_APP", "VISA_APP",],
      ["org", "PUBLIC_VISA_STAFF_URL", "base-org-ww", "operator",
       OperatorOidcAuthorizationTransaction, OperatorAuthAdmissionBinding, "BASE_ORG", "VISA_ORG",],
    ].each do |surface, visa_host_env, client_id, resource_type, transaction_class, binding_class,
                source_namespace, visa_namespace|
      host! ENV.fetch(visa_host_env)
      https!
      visa_origin = JumpRtSurface.issuer_origin(visa_namespace)
      client = OidcClientRegistry.find!(client_id)
      state = [
        SecureRandom.urlsafe_base64(12, padding: false),
        SecureRandom.urlsafe_base64(480, padding: false),
        SecureRandom.urlsafe_base64(31, padding: false),
      ].join(".")
      nonce = SecureRandom.urlsafe_base64(24, padding: false)
      parameters = {
        client_id: client_id,
        nonce: nonce,
        redirect_uri: client.redirect_uris_by_realm.fetch(resource_type).first,
        response_type: "id_token",
        ri: "jp",
        scope: "openid profile",
        state: state,
      }
      oidc_query = URI.encode_www_form(parameters)
      return_url = "#{visa_origin}/oauth/authorize?#{oidc_query}"
      jump_key = OpenSSL::PKey::RSA.generate(3_072)
      jump_kid = SecureRandom.uuid
      jump_jwk = JitSecurityJwtJwk.export_public(jump_key, kid: jump_kid)
      issued_at = Time.current.change(usec: 0)
      jump_payload = SecurityJwtJumpRtTokenCodec.build_issue_payload(
        issuer: Rails.configuration.x.boot_config.fetch(:jump).origin,
        normalized_url: return_url,
        dst: "internal",
        ttl: 30,
        now: issued_at,
        jti: SecureRandom.uuid,
        audience: visa_origin,
      ).merge(src: JumpRtSurface.return_origin(source_namespace))
      jump_rt = SecurityJwtJumpRtTokenCodec.encode(jump_payload, private_key: jump_key, kid: jump_kid)
      jwks_connection = VisaAuthorizationStartJwksConnection.new({ "keys" => [jump_jwk] }.to_json)
      transactions_before = transaction_class.count
      bindings_before = binding_class.count

      OutboundHttp::Connection.stub(:build, jwks_connection) do
        get "/oauth/authorize?#{oidc_query}&rt=#{jump_rt}", headers: {
          "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
        }
      end

      assert_response :see_other
      assert_equal "no-referrer", response.headers["Referrer-Policy"]
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      clean_query = Rack::Utils.parse_query(URI.parse(response.location).query)

      assert_not clean_query.key?("rt")
      assert_equal clean_query.fetch("state"), state

      follow_redirect!

      assert_equal 503, response.status, client_id
      assert_equal "no-referrer", response.headers["Referrer-Policy"]
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_equal transactions_before, transaction_class.count, surface
      assert_equal bindings_before, binding_class.count, surface
      assert_equal "temporarily_unavailable", response.parsed_body.fetch("error")
      assert_nil response.location
    end
  end

  test "unknown client and unregistered redirect URI fail locally in both realms" do
    [
      ["PUBLIC_VISA_SERVICE_URL", "base-app-ww", "client", ClientOidcAuthorizationTransaction],
      ["PUBLIC_VISA_STAFF_URL", "base-org-ww", "operator", OperatorOidcAuthorizationTransaction],
    ].each do |visa_host_env, client_id, resource_type, transaction_class|
      host! ENV.fetch(visa_host_env)
      https!
      client = OidcClientRegistry.find!(client_id)
      parameters = {
        response_type: "code",
        client_id: client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch(resource_type).first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "openid profile",
        state: "local-target-refusal",
        nonce: "local-target-refusal",
        ri: "jp",
      }

      [parameters.merge(client_id: "unknown-client"),
       parameters.merge(redirect_uri: "#{parameters.fetch(:redirect_uri)}-near-match"),].each do |invalid_parameters|
        before = transaction_class.count
        get "/oauth/authorize", params: invalid_parameters

        assert_response :bad_request
        assert_equal "invalid_request", response.parsed_body.fetch("error")
        assert_nil response.location
        assert_equal before, transaction_class.count
        assert_equal "no-referrer", response.headers["Referrer-Policy"]
        assert_includes response.headers.fetch("Cache-Control"), "no-store"
      end
    end
  end

  test "protocol errors after the registered redirect is trusted return through Jump with issuer and state" do
    [
      ["PUBLIC_VISA_SERVICE_URL", "base-app-ww", "client", ClientOidcAuthorizationTransaction],
      ["PUBLIC_VISA_STAFF_URL", "base-org-ww", "operator", OperatorOidcAuthorizationTransaction],
    ].each do |visa_host_env, client_id, resource_type, transaction_class|
      host! ENV.fetch(visa_host_env)
      https!
      client = OidcClientRegistry.find!(client_id)
      base_parameters = {
        response_type: "id_token",
        client_id: client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch(resource_type).first,
        scope: "openid profile",
        state: "trusted-target-state",
        nonce: "trusted-target-nonce",
        ri: "jp",
      }
      invalid_requests = [
        [base_parameters.merge(response_type: "code"), "unsupported_response_type"],
        [base_parameters.merge(response_type: "token"), "unsupported_response_type"],
        [base_parameters.merge(response_type: "id_token token"), "unsupported_response_type"],
        [base_parameters.merge(scope: "profile"), "invalid_request"],
        [base_parameters.merge(state: ""), "invalid_request"],
        [base_parameters.except(:nonce), "invalid_request"],
        [base_parameters.merge(code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"), "invalid_request"],
        [base_parameters.merge(code_challenge_method: "S256"), "invalid_request"],
      ]

      invalid_requests.each do |invalid_parameters, expected_error|
        before = transaction_class.count
        get "/oauth/authorize", params: invalid_parameters

        assert_response :redirect
        assert_equal before, transaction_class.count
        jump_uri = URI.parse(response.location)
        error_rt = Rack::Utils.parse_query(jump_uri.query).fetch("rt")
        error_target = URI.parse(JWT.decode(error_rt, nil, false).first.fetch("url"))
        error_parameters = Rack::Utils.parse_query(error_target.query)

        assert_equal expected_error, error_parameters.fetch("error")
        assert_equal error_parameters.fetch("iss"), OidcIssuer.for_resource_type(resource_type)
        if invalid_parameters.fetch(:state, "").present?
          assert_equal error_parameters.fetch("state"), invalid_parameters.fetch(:state)
        else
          assert_not error_parameters.key?("state")
        end

        assert_equal "no-referrer", response.headers["Referrer-Policy"]
        assert_includes response.headers.fetch("Cache-Control"), "no-store"
      end
    end
  end

  test "prompt none without an OP session returns login_required without allocating a transaction" do
    [
      ["PUBLIC_VISA_SERVICE_URL", "base-app-ww", "client", ClientOidcAuthorizationTransaction],
      ["PUBLIC_VISA_STAFF_URL", "base-org-ww", "operator", OperatorOidcAuthorizationTransaction],
    ].each do |visa_host_env, client_id, resource_type, transaction_class|
      host! ENV.fetch(visa_host_env)
      https!
      client = OidcClientRegistry.find!(client_id)
      state = SecureRandom.urlsafe_base64(24, padding: false)
      parameters = {
        response_type: "id_token",
        client_id: client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch(resource_type).first,
        scope: "openid profile",
        state: state,
        nonce: SecureRandom.urlsafe_base64(24, padding: false),
        prompt: "none",
        ri: "jp",
      }
      before = transaction_class.count

      get "/oauth/authorize", params: parameters

      assert_response :redirect
      assert_equal before, transaction_class.count
      error_rt = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("rt")
      error_target = URI.parse(JWT.decode(error_rt, nil, false).first.fetch("url"))
      error_parameters = Rack::Utils.parse_query(error_target.query)

      assert_equal "login_required", error_parameters.fetch("error")
      assert_equal error_parameters.fetch("state"), state
      assert_equal error_parameters.fetch("iss"), OidcIssuer.for_resource_type(resource_type)
    end
  end

  test "step-up requests stay unavailable and do not create a normal sign-in transaction" do
    [
      ["PUBLIC_VISA_SERVICE_URL", "base-app-ww", "client", ClientOidcAuthorizationTransaction],
      ["PUBLIC_VISA_STAFF_URL", "base-org-ww", "operator", OperatorOidcAuthorizationTransaction],
    ].each do |visa_host_env, client_id, resource_type, transaction_class|
      host! ENV.fetch(visa_host_env)
      https!
      client = OidcClientRegistry.find!(client_id)
      parameters = {
        response_type: "id_token",
        client_id: client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch(resource_type).first,
        scope: "openid profile",
        state: "step-up-refusal",
        nonce: "step-up-refusal",
        claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
        acr_values: OidcAuthorizeRequestResolver::STEP_UP_ACR,
        ri: "jp",
      }
      before = transaction_class.count

      get "/oauth/authorize", params: parameters

      assert_response :redirect
      assert_equal before, transaction_class.count
      error_rt = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("rt")
      error_target = URI.parse(JWT.decode(error_rt, nil, false).first.fetch("url"))
      error_parameters = Rack::Utils.parse_query(error_target.query)

      assert_equal "unmet_authentication_requirements", error_parameters.fetch("error")
    end
  end

  test "App prompt create and both realm prompt login values fail closed before allocation" do
    [
      ["PUBLIC_VISA_SERVICE_URL", "base-app-ww", "client",
       ClientOidcAuthorizationTransaction, "create", "auth_service",],
      ["PUBLIC_VISA_SERVICE_URL", "base-app-ww", "client",
       ClientOidcAuthorizationTransaction, "login", "auth_service",],
      ["PUBLIC_VISA_STAFF_URL", "base-org-ww", "operator",
       OperatorOidcAuthorizationTransaction, "login", "auth_staff",],
    ].each do |visa_host_env, client_id, resource_type, transaction_class, prompt, auth_host_kind|
      host! ENV.fetch(visa_host_env)
      https!
      client = OidcClientRegistry.find!(client_id)
      state = SecureRandom.urlsafe_base64(24, padding: false)
      parameters = {
        response_type: "id_token",
        client_id: client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch(resource_type).first,
        scope: "openid profile",
        state: state,
        nonce: SecureRandom.urlsafe_base64(24, padding: false),
        prompt: prompt,
        ri: "jp",
      }

      transaction_count = transaction_class.count
      get "/oauth/authorize", params: parameters

      assert_equal 503, response.status, "#{client_id} prompt=#{prompt}"
      assert_equal transaction_count, transaction_class.count
      assert_nil response.location
      assert_equal "temporarily_unavailable", response.parsed_body.fetch("error")
      assert_equal "no-referrer", response.headers["Referrer-Policy"]
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
    end
  end

  test "Org prompt create remains refused by the realm request contract" do
    host! ENV.fetch("PUBLIC_VISA_STAFF_URL")
    https!
    client = OidcClientRegistry.find!("base-org-ww")
    parameters = {
      response_type: "id_token",
      client_id: "base-org-ww",
      redirect_uri: client.redirect_uris_by_realm.fetch("operator").first,
      scope: "openid profile",
      state: "org-create-prompt",
      nonce: "org-create-prompt",
      prompt: "create",
      ri: "jp",
    }
    before = OperatorOidcAuthorizationTransaction.count

    get "/oauth/authorize", params: parameters

    assert_response :bad_request
    assert_equal before, OperatorOidcAuthorizationTransaction.count
    assert_nil response.location
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "App and Org clients are refused at the opposite realm before redirect" do
    [
      ["PUBLIC_VISA_STAFF_URL", "base-app-ww", "client", "operator", OperatorOidcAuthorizationTransaction],
      ["PUBLIC_VISA_SERVICE_URL", "base-org-ww", "operator", "client", ClientOidcAuthorizationTransaction],
    ].each do |visa_host_env, client_id, client_resource_type, endpoint_resource_type, transaction_class|
      host! ENV.fetch(visa_host_env)
      https!
      client = OidcClientRegistry.find!(client_id)
      parameters = {
        response_type: "id_token",
        client_id: client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch(client_resource_type).first,
        scope: "openid profile",
        state: "cross-realm-refusal",
        nonce: "cross-realm-refusal",
        ri: "jp",
      }
      before = transaction_class.count

      get "/oauth/authorize", params: parameters

      assert_response :bad_request
      assert_equal before, transaction_class.count
      assert_nil response.location
      assert_equal "invalid_request", response.parsed_body.fetch("error")
      assert_equal "no-referrer", response.headers["Referrer-Policy"]
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_includes ["client", "operator"], endpoint_resource_type
    end
  end

  test "authorization query and parameter size limits accept the boundary and reject the next byte" do
    ["PUBLIC_VISA_SERVICE_URL", "PUBLIC_VISA_STAFF_URL"].each do |visa_host_env|
      [8_191, 8_192, 8_193].each do |query_bytes|
        host! ENV.fetch(visa_host_env)
        https!
        query = "client_id=unknown-client&ri=jp"
        remaining = query_bytes - query.bytesize
        chunk = 0
        while remaining.positive?
          key = "x#{chunk}"
          prefix_bytes = key.bytesize + 2
          value_bytes = [OauthAuthorizeRequestSizeLimit::MAX_PARAMETER_BYTES, remaining - prefix_bytes].min
          query += "&#{key}=#{"a" * value_bytes}"
          remaining -= prefix_bytes + value_bytes
          chunk += 1
        end

        get "/oauth/authorize?#{query}"

        assert_response :bad_request
        too_large = response.parsed_body.fetch("error_description").include?("too large")

        assert_equal query_bytes > OauthAuthorizeRequestSizeLimit::MAX_QUERY_BYTES, too_large
      end

      [2_047, 2_048, 2_049].each do |parameter_bytes|
        host! ENV.fetch(visa_host_env)
        https!
        get "/oauth/authorize?client_id=unknown-client&ri=jp&x=#{"a" * parameter_bytes}"

        assert_response :bad_request
        too_large = response.parsed_body.fetch("error_description").include?("too large")

        assert_equal parameter_bytes > OauthAuthorizeRequestSizeLimit::MAX_PARAMETER_BYTES, too_large
      end
    end
  end

  test "authorization start rate limit refuses before transaction allocation" do
    profile = RateLimitProfiles.oauth_authorize.ip_surface
    store = Rails.configuration.x.rate_limit.fetch(:store)
    [
      ["PUBLIC_VISA_SERVICE_URL", "base-app-ww", "client", ClientOidcAuthorizationTransaction],
      ["PUBLIC_VISA_STAFF_URL", "base-org-ww", "operator", OperatorOidcAuthorizationTransaction],
    ].each do |visa_host_env, client_id, resource_type, transaction_class|
      host! ENV.fetch(visa_host_env)
      https!
      client = OidcClientRegistry.find!(client_id)
      parameters = {
        response_type: "code",
        client_id: client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch(resource_type).first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        scope: "openid profile",
        state: "rate-limit-refusal",
        nonce: "rate-limit-refusal",
        ri: "jp",
      }
      before = transaction_class.count

      increment =
        lambda do |key, *_arguments, **_keywords|
          key.include?("oauth_authorize") ? profile.to + 1 : 1
        end
      store.stub(:increment, increment) do
        get "/oauth/authorize", params: parameters, headers: { "Accept" => "application/json" }
      end

      assert_response :too_many_requests
      assert_equal "oauth_authorize_ip_surface", response.headers.fetch("X-RateLimit-Rule")
      assert_predicate response.headers.fetch("Retry-After"), :present?
      assert_equal before, transaction_class.count
      assert_equal "no-referrer", response.headers["Referrer-Policy"]
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
    end
  end

  test "HEAD and continuation fields are rejected locally in both realms" do
    [
      ["PUBLIC_VISA_SERVICE_URL", ClientOidcAuthorizationTransaction],
      ["PUBLIC_VISA_STAFF_URL", OperatorOidcAuthorizationTransaction],
    ].each do |visa_host_env, transaction_class|
      host! ENV.fetch(visa_host_env)
      https!
      before = transaction_class.count

      head "/oauth/authorize", params: { client_id: "untrusted" }

      assert_response :bad_request
      assert_nil response.location
      assert_equal before, transaction_class.count

      %w(result result_ref transaction_ref cancellation_ref switch_handoff continuation restart_of).each do |name|
        get "/oauth/authorize", params: { :client_id => "untrusted", name => "" }

        assert_response :bad_request
        assert_nil response.location
        assert_equal before, transaction_class.count
      end
    end
  end
end
