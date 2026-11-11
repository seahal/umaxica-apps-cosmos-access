# frozen_string_literal: true

require "test_helper"

class OidcAuthorizationParameterMultiplicityTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  %w(app org).each do |realm|
    %w(get post).each do |verb|
      %w(
        response_type client_id redirect_uri state code_challenge code_challenge_method
        scope nonce prompt max_age claims acr_values
      ).each do |field|
        test "#{realm} #{verb} refuses repeated #{field} before allocating an authorization" do
          type = (realm == "app") ? "client" : "operator"
          client = OidcClientRegistry.find!(RpDeploymentBindingValue.client_id("base-#{realm}"))
          host!(OidcIssuer.host_for_resource_type(type))
          pairs =
            {
              response_type: "code",
              client_id: client.client_id,
              redirect_uri: client.redirect_uris_by_realm.fetch(type).first,
              scope: "openid",
              state: "request-state",
              nonce: "request-nonce",
              code_challenge: "a" * 43,
              code_challenge_method: "S256",
              prompt: "none",
              max_age: "0",
              claims: "",
              acr_values: "",
            }.map { |key, value| [key.to_s, value] }
          pairs << pairs.find { |key, _value| key == field }
          body = URI.encode_www_form(pairs)
          app_before = ClientOidcAuthorizationTransaction.count
          org_before = OperatorOidcAuthorizationTransaction.count

          if verb == "get"
            get "/oauth/authorize?#{body}"
          elsif verb == "post"
            post "/oauth/authorize", params: "ceremony_action=start&#{body}",
                                     headers: { "CONTENT_TYPE" => "application/x-www-form-urlencoded" }
          end

          if %w(client_id redirect_uri).include?(field)
            assert_response :bad_request
            assert_nil response.headers["Location"]
            assert_equal "invalid_request", response.parsed_body.fetch("error")
          else
            assert_response :redirect
            location = URI(response.headers.fetch("Location"))
            payload = JWT.decode(URI.decode_www_form(location.query).to_h.fetch("rt"), nil, false).first
            destination = URI(payload.fetch("url"))
            expected = URI(client.redirect_uris_by_realm.fetch(type).first)

            assert_equal expected.host, destination.host
            assert_equal expected.path, destination.path
            assert_equal "invalid_request", URI.decode_www_form(destination.query).to_h.fetch("error")
          end

          assert_equal app_before, ClientOidcAuthorizationTransaction.count
          assert_equal org_before, OperatorOidcAuthorizationTransaction.count
          assert_includes response.headers.fetch("Cache-Control"), "no-store"
        end
      end
    end
  end

  test "encoded field names and repetitions across query and POST body are refused" do
    client = OidcClientRegistry.find!(RpDeploymentBindingValue.client_id("base-app"))
    host!(OidcIssuer.host_for_resource_type("client"))
    parameters = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      scope: "openid",
      state: "request-state",
      nonce: "request-nonce",
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
    }
    before = ClientOidcAuthorizationTransaction.count

    body = URI.encode_www_form(parameters.merge(ceremony_action: "start"))
    post "/oauth/authorize?%73tate=query-state", params: body,
                                                 headers: { "CONTENT_TYPE" => "application/x-www-form-urlencoded" }

    assert_response :redirect
    payload = JWT.decode(
      URI.decode_www_form(URI(response.headers.fetch("Location")).query).to_h.fetch("rt"),
      nil, false,
    ).first

    assert_equal "invalid_request", URI.decode_www_form(URI(payload.fetch("url")).query).to_h.fetch("error")
    assert_equal before, ClientOidcAuthorizationTransaction.count
  end

  test "unsafe client with another repeated parameter stays local" do
    host!(OidcIssuer.host_for_resource_type("client"))

    query = URI.encode_www_form(client_id: "unregistered", redirect_uri: "https://outside.example/callback")

    get "/oauth/authorize?#{query}&scope=openid&scope=openid"

    assert_response :bad_request
    assert_nil response.headers["Location"]
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "unsafe redirect with another repeated parameter stays local" do
    client = OidcClientRegistry.find!(RpDeploymentBindingValue.client_id("base-app"))
    host!(OidcIssuer.host_for_resource_type("client"))
    query = URI.encode_www_form(client_id: client.client_id, redirect_uri: "https://outside.example/callback")

    get "/oauth/authorize?#{query}&scope=openid&scope=openid"

    assert_response :bad_request
    assert_nil response.headers["Location"]
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "one recognized occurrence and repeated unknown fields retain the normal protocol error" do
    client = OidcClientRegistry.find!(RpDeploymentBindingValue.client_id("base-app"))
    host!(OidcIssuer.host_for_resource_type("client"))
    query = URI.encode_www_form(
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      response_type: "token", state: "request-state",
    )

    get "/oauth/authorize?#{query}&unknown=one&unknown=two"

    assert_response :redirect
    payload = JWT.decode(
      URI.decode_www_form(URI(response.headers.fetch("Location")).query).to_h.fetch("rt"),
      nil, false,
    ).first

    assert_equal "unsupported_response_type", URI.decode_www_form(URI(payload.fetch("url")).query).to_h.fetch("error")
  end

  test "one occurrence of each required field retains the normal unauthenticated refusal" do
    client = OidcClientRegistry.find!(RpDeploymentBindingValue.client_id("base-app"))
    host!(OidcIssuer.host_for_resource_type("client"))
    query = URI.encode_www_form(
      response_type: "code", client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      scope: "openid", state: "request-state", nonce: "request-nonce",
      code_challenge: "a" * 43, code_challenge_method: "S256", prompt: "none",
    )
    before = ClientOidcAuthorizationTransaction.count

    get "/oauth/authorize?#{query}"

    assert_response :redirect
    payload = JWT.decode(
      URI.decode_www_form(URI(response.headers.fetch("Location")).query).to_h.fetch("rt"), nil, false,
    ).first

    assert_equal "login_required", URI.decode_www_form(URI(payload.fetch("url")).query).to_h.fetch("error")
    assert_equal before, ClientOidcAuthorizationTransaction.count
  end

  test "three encoded or empty target occurrences stay local even when normalized to a valid client" do
    client = OidcClientRegistry.find!(RpDeploymentBindingValue.client_id("base-app"))
    host!(OidcIssuer.host_for_resource_type("client"))
    query = URI.encode_www_form(redirect_uri: client.redirect_uris_by_realm.fetch("client").first)
    query += "&client_id=&%63lient_id=&client_id=#{URI.encode_www_form_component(client.client_id)}"

    get "/oauth/authorize?#{query}"

    assert_response :bad_request
    assert_nil response.headers["Location"]
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "multipart form repetitions are refused before transaction allocation" do
    client = OidcClientRegistry.find!(RpDeploymentBindingValue.client_id("base-app"))
    host!(OidcIssuer.host_for_resource_type("client"))
    fields = [
      ["ceremony_action", "start"], ["client_id", client.client_id],
      ["redirect_uri", client.redirect_uris_by_realm.fetch("client").first],
      ["scope", "openid"], ["scope", "profile"],
    ]
    body = fields.map do |name, value|
      "--authorization-boundary\r\nContent-Disposition: form-data; name=\"#{name}\"\r\n\r\n#{value}\r\n"
    end.join + "--authorization-boundary--\r\n"
    before = ClientOidcAuthorizationTransaction.count

    post "/oauth/authorize", params: body,
                             headers: { "CONTENT_TYPE" => "multipart/form-data; boundary=authorization-boundary" }

    assert_response :redirect
    payload = JWT.decode(
      URI.decode_www_form(URI(response.headers.fetch("Location")).query).to_h.fetch("rt"), nil, false,
    ).first

    assert_equal "invalid_request", URI.decode_www_form(URI(payload.fetch("url")).query).to_h.fetch("error")
    assert_equal before, ClientOidcAuthorizationTransaction.count
  end
end
