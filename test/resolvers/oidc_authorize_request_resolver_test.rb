# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcAuthorizeRequestResolverTest < ActiveSupport::TestCase
  setup do
    @client = OidcClientRegistry.find!("core-app-jp")
    @resource = nil
    @resource_type = "client"
    @params = {
      response_type: "code",
      client_id: @client.client_id,
      redirect_uri: @client.redirect_uris.first,
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid profile",
    }
  end

  test "normalizes supported prompt and max_age values" do
    result = OidcAuthorizeRequestResolver.call(
      params: @params.merge(prompt: "login", max_age: "300"),
      resource: @resource, resource_type: @resource_type,
    )

    assert_equal "login", result.prompt
    assert_equal 300, result.max_age

    create_result = OidcAuthorizeRequestResolver.call(
      params: @params.merge(prompt: "create"), resource: @resource, resource_type: @resource_type,
    )

    assert_equal "create", create_result.prompt
  end

  test "accepts the registered Base App front-channel ID Token request without PKCE" do
    client = OidcClientRegistry.find!("base-app-ww")
    params = {
      response_type: "id_token",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      state: "front-channel-state",
      nonce: "front-channel-nonce",
      scope: "openid profile",
    }

    result = OidcAuthorizeRequestResolver.call(params:, resource: nil, resource_type: "client")

    assert_equal client, result.client
    assert_equal "openid profile", result.scope
  end

  test "accepts the registered Base Org front-channel ID Token request without PKCE" do
    client = OidcClientRegistry.find!("base-org-ww")
    params = {
      response_type: "id_token",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("operator").first,
      state: "front-channel-state",
      nonce: "front-channel-nonce",
      scope: "openid profile",
    }

    result = OidcAuthorizeRequestResolver.call(params:, resource: nil, resource_type: "operator")

    assert_equal client, result.client
    assert_equal "openid profile", result.scope
  end

  test "Base clients refuse code, other clients refuse ID Tokens, and all clients refuse Hybrid types" do
    app_client = OidcClientRegistry.find!("base-app-ww")
    org_client = OidcClientRegistry.find!("base-org-ww")
    other_client = OidcClientRegistry.find!("core-app-jp")
    requests = [
      [app_client, "client", "code", :unsupported_response_type],
      [org_client, "operator", "code", :unsupported_response_type],
      [other_client, "client", "id_token", :unsupported_response_type],
      [other_client, "client", "id_token token", :unsupported_response_type],
      [other_client, "client", "code id_token", :unsupported_response_type],
      [other_client, "client", "id_token code", :unsupported_response_type],
      [other_client, "client", "code token", :unsupported_response_type],
      [other_client, "client", "token code", :unsupported_response_type],
      [other_client, "client", "code id_token token", :unsupported_response_type],
      [other_client, "client", "token id_token code", :unsupported_response_type],
    ]

    requests.each do |client, resource_type, response_type, expected_error|
      base = {
        response_type:,
        client_id: client.client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch(resource_type).first,
        scope: "openid profile",
        state: "front-channel-state",
        nonce: "front-channel-nonce",
      }
      base.merge!(code_challenge: @params.fetch(:code_challenge), code_challenge_method: "S256") if
        response_type.start_with?("code")

      error = assert_raises(OidcAuthorizeRequestResolver::RequestError) do
        OidcAuthorizeRequestResolver.call(params: base, resource: nil, resource_type:)
      end

      assert_equal expected_error.to_s, error.error
    end
  end

  test "Base front-channel requests reject every PKCE parameter including blank values" do
    client = OidcClientRegistry.find!("base-app-ww")
    base = {
      response_type: "id_token",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      state: "front-channel-state",
      nonce: "front-channel-nonce",
      scope: "openid profile",
    }

    [
      { code_challenge: @params.fetch(:code_challenge) },
      { code_challenge_method: "S256" },
      { code_challenge: "", code_challenge_method: "" },
    ].each do |pkce_parameters|
      error = assert_raises(OidcAuthorizeRequestResolver::RequestError) do
        OidcAuthorizeRequestResolver.call(
          params: base.merge(pkce_parameters), resource: nil, resource_type: "client",
        )
      end

      assert_equal "invalid_request", error.error
    end
  end

  test "Base front-channel requests require state and nonce" do
    client = OidcClientRegistry.find!("base-app-ww")
    base = {
      response_type: "id_token",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      state: "front-channel-state",
      nonce: "front-channel-nonce",
      scope: "openid profile",
    }

    [{ state: nil }, { state: "" }, { nonce: nil }, { nonce: "" }].each do |missing_parameter|
      error = assert_raises(OidcAuthorizeRequestResolver::RequestError) do
        OidcAuthorizeRequestResolver.call(
          params: base.merge(missing_parameter), resource: nil, resource_type: "client",
        )
      end

      assert_equal "invalid_request", error.error
    end
  end

  test "recognizes the canonical essential step-up claims request" do
    result = OidcAuthorizeRequestResolver.call(
      params: @params.merge(prompt: "login", claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS),
      resource: @resource, resource_type: @resource_type,
    )

    assert result.step_up_requested
    assert_equal "login", result.prompt
  end

  test "accepts only matching acr_values alongside the canonical claims request" do
    result = OidcAuthorizeRequestResolver.call(
      params: @params.merge(
        claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
        acr_values: OidcAuthorizeRequestResolver::STEP_UP_ACR,
      ),
      resource: @resource, resource_type: @resource_type,
    )

    assert result.step_up_requested

    error =
      assert_raises(OidcAuthorizeRequestResolver::RequestError) do
        OidcAuthorizeRequestResolver.call(
          params: @params.merge(
            claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
            acr_values: "https://visa.umaxica.app/acr/other",
          ),
          resource: @resource, resource_type: @resource_type,
        )
      end
    assert_equal "invalid_request", error.error
  end

  test "the exact step-up class is supported on ORG and class comparison is case-sensitive" do
    org_client = OidcClientRegistry.find!("core-org-jp")
    org_params = @params.merge(
      client_id: org_client.client_id,
      redirect_uri: org_client.redirect_uris_by_realm.fetch("operator").first,
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    )

    result = OidcAuthorizeRequestResolver.call(
      params: org_params, resource: nil, resource_type: "operator",
    )

    assert result.step_up_requested

    changed_class = JSON.generate(
      "id_token" => {
        "acr" => { "essential" => true, "value" => OidcAuthorizeRequestResolver::STEP_UP_ACR.upcase },
        "auth_time" => { "essential" => true },
      },
    )
    error =
      assert_raises(OidcAuthorizeRequestResolver::UnmetAuthenticationRequirements) do
        OidcAuthorizeRequestResolver.call(
          params: org_params.merge(claims: changed_class), resource: nil, resource_type: "operator",
        )
      end

    assert_equal "unmet_authentication_requirements", error.error
  end

  test "distinguishes an unsupported essential authentication class from malformed claims" do
    unsupported_claims = JSON.generate(
      "id_token" => {
        "acr" => { "essential" => true, "value" => "https://visa.umaxica.app/acr/unsupported" },
        "auth_time" => { "essential" => true },
      },
    )
    error =
      assert_raises(OidcAuthorizeRequestResolver::UnmetAuthenticationRequirements) do
        OidcAuthorizeRequestResolver.call(
          params: @params.merge(claims: unsupported_claims), resource: @resource, resource_type: @resource_type,
        )
      end
    assert_equal "unmet_authentication_requirements", error.error

    malformed =
      assert_raises(OidcAuthorizeRequestResolver::RequestError) do
        OidcAuthorizeRequestResolver.call(
          params: @params.merge(claims: "{"), resource: @resource, resource_type: @resource_type,
        )
      end
    assert_equal "invalid_request", malformed.error

    acr_only =
      assert_raises(OidcAuthorizeRequestResolver::RequestError) do
        OidcAuthorizeRequestResolver.call(
          params: @params.merge(acr_values: OidcAuthorizeRequestResolver::STEP_UP_ACR),
          resource: @resource, resource_type: @resource_type,
        )
      end
    assert_equal "invalid_request", acr_only.error
  end

  test "rejects prompt combinations and negative max_age" do
    { "none login" => "prompt must be a single value", "consent" => "prompt value is not supported" }
      .each do |prompt, message|
        error =
          assert_raises(OidcAuthorizeRequestResolver::UnsupportedPrompt) do
            OidcAuthorizeRequestResolver.call(
              params: @params.merge(prompt: prompt), resource: @resource, resource_type: @resource_type,
            )
          end
        assert_equal message, error.message
      end

    error =
      assert_raises(ArgumentError) do
        OidcAuthorizeRequestResolver.call(
          params: @params.merge(max_age: "-1"), resource: @resource, resource_type: @resource_type,
        )
      end
    assert_equal "max_age must be a non-negative integer", error.message
  end

  test "rejects create for the Org surface" do
    org_client = OidcClientRegistry.find!("core-org-jp")
    error =
      assert_raises(OidcAuthorizeRequestResolver::UnsupportedPrompt) do
        OidcAuthorizeRequestResolver.call(
          params: @params.merge(
            prompt: "create", client_id: org_client.client_id,
            redirect_uri: org_client.redirect_uris_by_realm.fetch("operator").first,
          ),
          resource: nil, resource_type: "operator",
        )
      end

    assert_equal "prompt value is not supported", error.message
  end
end
