# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcEndSessionRequestTest < ActiveSupport::TestCase
  Request =
    Data.define(:host, :method) do
      def get? = method == "GET"

      def head? = method == "HEAD"
    end

  setup do
    @client = OidcClientRegistry.find!("core-app-jp")
    @subject = "cli_#{SecureRandom.alphanumeric(21)}"
    @sid = SecureRandom.uuid
    @request = Request.new(host: URI.parse("//#{OidcIssuer.host_for_resource_type("client")}").host, method: "POST")
    Actor.clear
  end

  teardown do
    Actor.clear
  end

  test "returns confirmation for no-hint request" do
    result = call({})

    assert_predicate result, :success?
    assert_predicate result, :requires_confirmation?
    assert_equal :no_hint, result.source
  end

  test "accepts an exact registered return for a no-hint RP completion" do
    redirect_uri = @client.post_logout_redirect_uris.first
    result = OidcEndSessionRequest.call(
      params: {
        client_id: @client.client_id,
        post_logout_redirect_uri: redirect_uri,
        state: "rp-cell-state",
      },
      request: @request,
    )

    assert_predicate result, :success?
    assert_predicate result, :requires_confirmation?
    assert_equal :no_hint, result.source
    assert_equal @client, result.client
    assert_equal @client.client_id, result.client_id
    assert_equal redirect_uri, result.post_logout_redirect_uri
    assert_equal "rp-cell-state", result.state
  end

  test "rejects an unregistered no-hint RP return before preserving its state" do
    result = OidcEndSessionRequest.call(
      params: {
        client_id: @client.client_id,
        post_logout_redirect_uri: "https://attacker.example/signed-out",
        state: "attacker-state",
      },
      request: @request,
    )

    assert_predicate result, :error?
    assert_equal "invalid_request", result.error_code
    assert_nil result.post_logout_redirect_uri
    assert_nil result.state
  end

  test "returns the grant sid from a verified RP hint for the Visa boundary to authorize" do
    result = call(id_token_hint: id_token(sid: "rp-grant-public-id"))

    assert_predicate result, :success?
    assert_equal :id_token_hint, result.source
    assert_equal @client.client_id, result.client_id
    assert_equal @subject, result.subject
    assert_equal "rp-grant-public-id", result.sid
  end

  test "id_token_hint takes precedence over legacy logout_request" do
    legacy = OidcLogoutRequest.issue(client_id: "core-app-jp", ri: "jp")

    result = call(id_token_hint: id_token, logout_request: legacy)

    assert_predicate result, :success?
    assert_equal :id_token_hint, result.source
    assert_not_nil OidcLogoutRequest.verify(legacy), "id_token_hint path must not consume legacy logout_request"
  end

  test "rejects tampered id_token_hint" do
    result = call(id_token_hint: "#{id_token}x")

    assert_predicate result, :error?
    assert_equal "invalid_request", result.error_code
  end

  test "accepts expired id_token_hint for end-session while validating its issuer and signature" do
    result = call(id_token_hint: id_token(issued_at: 10.minutes.ago, expires_at: 1.minute.ago))

    assert_predicate result, :success?
    assert_equal @client.client_id, result.client_id
    assert_equal @sid, result.sid
  end

  test "rejects a not-yet-valid id_token_hint even for end-session" do
    result = call(id_token_hint: id_token(issued_at: 5.minutes.from_now, expires_at: 10.minutes.from_now))

    assert_predicate result, :error?
    assert_equal "invalid_request", result.error_code
  end

  test "rejects client_id mismatch" do
    result = call(id_token_hint: id_token, client_id: "core-com-jp")

    assert_predicate result, :error?
    assert_equal "client_id mismatch", result.error_description
  end

  test "returns the verified hint subject and sid without loading an account record" do
    result = call(id_token_hint: id_token)

    assert_predicate result, :success?
    assert_equal @subject, result.subject
  end

  test "returns the hint sid rather than substituting the authenticated session" do
    result = call(id_token_hint: id_token(sid: "unrelated-rp-grant-public-id"))

    assert_predicate result, :success?
    assert_equal "unrelated-rp-grant-public-id", result.sid
  end

  test "requires confirmation for valid id_token_hint without current session" do
    result = call(id_token_hint: id_token)

    assert_predicate result, :success?
    assert_predicate result, :requires_confirmation?
  end

  test "accepts exact registered post logout redirect uri and state" do
    uri = @client.post_logout_redirect_uris.first

    result = call(id_token_hint: id_token, post_logout_redirect_uri: uri, state: "xyz")

    assert_predicate result, :success?
    assert_equal uri, result.post_logout_redirect_uri
    assert_equal "xyz", result.state
  end

  test "rejects unregistered post logout redirect uri without echoing state" do
    result = call(
      id_token_hint: id_token,
      post_logout_redirect_uri: "https://attacker.example/signed-out",
      state: "xyz",
    )

    assert_predicate result, :error?
    assert_nil result.state
    assert_nil result.post_logout_redirect_uri
  end

  test "rejects post logout redirect uri registered for another realm" do
    cross_realm_uri = OidcClientRegistry.find!("core-org-jp").post_logout_redirect_uris.first

    assert_not_nil cross_realm_uri, "core-org-jp should register an org-realm post_logout uri"

    result = call(id_token_hint: id_token, post_logout_redirect_uri: cross_realm_uri, state: "xyz")

    assert_predicate result, :error?
    assert_nil result.state
    assert_nil result.post_logout_redirect_uri
  end

  test "legacy logout_request verifies on post and preserves replay protection" do
    token = OidcLogoutRequest.issue(client_id: "core-app-jp", ri: "jp")

    first = call({ logout_request: token })
    second = call({ logout_request: token })

    assert_predicate first, :success?
    assert_equal :logout_request, first.source
    assert_equal "jp", first.legacy_ri
    assert_predicate second, :error?
  end

  test "legacy logout_request is not consumed on get" do
    token = OidcLogoutRequest.issue(client_id: "core-app-jp", ri: "jp")
    get_request = Request.new(host: @request.host, method: "GET")

    result = OidcEndSessionRequest.call(params: { logout_request: token }, request: get_request)

    assert_predicate result, :success?
    assert_predicate result, :requires_confirmation?
    assert_not_nil OidcLogoutRequest.verify(token)
  end

  # HEAD shares Rails routing with GET, so it must not consume the single-use logout_request token.
  test "legacy logout_request is not consumed on head" do
    token = OidcLogoutRequest.issue(client_id: "core-app-jp", ri: "jp")
    head_request = Request.new(host: @request.host, method: "HEAD")

    result = OidcEndSessionRequest.call(params: { logout_request: token }, request: head_request)

    assert_predicate result, :success?
    assert_predicate result, :requires_confirmation?
    assert_equal :logout_request, result.source
    assert_not_nil OidcLogoutRequest.verify(token)
  end

  private

  def call(params)
    OidcEndSessionRequest.call(params: params, request: @request)
  end

  def id_token(issued_at: Time.current, expires_at: 5.minutes.from_now, sid: @sid)
    OidcIdTokenIssuer.call(
      resource_type: "client",
      client: @client,
      nonce: "nonce",
      issued_at: issued_at,
      expires_at: expires_at,
      issuer: OidcIssuer.for_resource_type("client"),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
      subject: @subject,
      sid: sid,
    )
  end
end
