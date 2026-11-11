# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class JumpRtReturnVerificationTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @jump_private_key = OpenSSL::PKey::EC.generate("secp384r1")
    @jump_public_jwk = JWT::JWK.new(@jump_private_key, kid: "jump-test").export.stringify_keys.except("d").merge(
      "alg" => "ES384",
      "use" => "sig",
    )
    @rails_private_key = OpenSSL::PKey::EC.generate("secp384r1")
    @rails_public_jwk = JWT::JWK.new(@rails_private_key, kid: "auth-app-test").export.stringify_keys.except("d").merge(
      "alg" => "ES384",
      "use" => "sig",
    )
    @now = Time.current.change(usec: 0)
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @previous_cache
  end

  test "Visa issued rt can round trip through a stubbed jump gateway to the Auth sign in page" do
    JumpRtKeyring.stub(:active_kid, "auth-app-test") do
      JumpRtKeyring.stub(:private_key, @rails_private_key) do
        app_origin = auth_app_origin
        rails_rt = JumpRtIssuer.call(
          namespace: "VISA_APP",
          url: "#{app_origin}/sign/in",
          dst: "internal",
          now: @now,
          jti: "rails-jti",
        )

        returned_location = stubbed_jump_location(rails_rt)
        returned_rt = Rack::Utils.parse_nested_query(URI.parse(returned_location).query).fetch("rt")
        prime_jump_jwks_cache

        https!
        get "#{app_origin}/sign/in", params: { rt: returned_rt }
      end
    end

    assert_response :see_other
    assert_equal "#{auth_app_origin}/sign/in", response.location
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))
  end

  test "Auth app consumes valid jump return rt from an external RP and strips it from the sign in url" do
    app_origin = auth_app_origin
    https!
    token = sign_return_token(
      aud: app_origin,
      src: JumpRtSurface.return_origin("BASE_APP"),
      url: "#{app_origin}/sign/in?ok=1",
    )

    prime_jump_jwks_cache
    get "#{app_origin}/sign/in", params: { ok: "1", rt: token }

    assert_response :see_other
    assert_equal "#{app_origin}/sign/in?ok=1", response.location
  end

  test "Auth app rejects invalid jump return rt before normal sign in" do
    app_origin = auth_app_origin
    https!

    get "#{app_origin}/sign/in", params: { rt: "not-a-jwt" }

    assert_response :bad_request
  end

  test "a signed return with a source path is rejected without redirecting" do
    app_origin = auth_app_origin
    https!
    token = sign_return_token(
      aud: app_origin,
      src: "#{JumpRtSurface.issuer_origin("AUTH_APP")}/unexpected",
      url: "#{app_origin}/sign/in?ok=1",
    )
    prime_jump_jwks_cache
    get "#{app_origin}/sign/in", params: { ok: "1", rt: token }

    assert_response :bad_request
    assert_nil response.location
  end

  test "rejected jump return logs do not include the rt token" do
    app_origin = auth_app_origin
    https!
    token = "aaaaaaaa.bbbbbbbb.cccccccc"
    log_io = StringIO.new
    previous_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log_io)
    begin
      get("#{app_origin}/sign/in", params: { rt: token })
    ensure
      Rails.logger = previous_logger
    end
    joined = log_io.string

    assert_response :bad_request
    assert_includes joined, "jump_return.rejected"
    assert_not_includes joined, token
    assert_no_match(/rt=#{Regexp.escape(token)}/, joined)
  end

  # Receiver responsibility (adr/jump-directed-rails-handoff-contract.md): a verified return only
  # removes rt and re-enters the same request URL on the receiving host. A downstream redirect
  # parameter carried through Jump is never followed by the return step itself.
  test "a verified Jump return does not follow a downstream redirect parameter off the receiving host" do
    origin = "https://auth.umaxica.org"
    url = "#{origin}/sign/in?redirect_uri=https%3A%2F%2Fevil.example%2Fcb&ri=us"
    token = sign_return_token(aud: origin, src: "https://www.umaxica.org", url: url)
    prime_jump_jwks_cache
    host! "auth.umaxica.org"
    https!
    get "/sign/in", params: { redirect_uri: "https://evil.example/cb", ri: "us", rt: token }

    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal "auth.umaxica.org", location.host
    assert_equal "https://evil.example/cb", Rack::Utils.parse_nested_query(location.query).fetch("redirect_uri")
    assert_not_includes Rack::Utils.parse_nested_query(location.query).keys, "rt"
  end

  test "a Jump return whose source edge is not approved is rejected even with a valid signature" do
    origin = "https://auth.umaxica.org"
    token = sign_return_token(aud: origin, src: "https://jp.umaxica.com", url: "#{origin}/sign/in?ri=us")
    prime_jump_jwks_cache
    host! "auth.umaxica.org"
    https!
    get "/sign/in", params: { ri: "us", rt: token }

    assert_response :bad_request
  end

  test "a verified Jump return redirects to the signed target with order and repeated pairs intact" do
    origin = "https://auth.umaxica.org"
    token = sign_return_token(
      aud: origin, src: "https://www.umaxica.org", url: "#{origin}/sign/in?ri=us&tag=b&tag=a&q=a%2Bb",
    )
    prime_jump_jwks_cache
    host! "auth.umaxica.org"
    https!
    get "/sign/in?ri=us&tag=b&rt=#{token}&tag=a&q=a%2Bb"

    assert_response :see_other
    assert_equal "#{origin}/sign/in?ri=us&tag=b&tag=a&q=a%2Bb", response.location
  end

  {
    "reordered pairs" => "tag=a&ri=us&tag=b&rt=%<token>s",
    "a second rt" => "ri=us&tag=b&tag=a&rt=%<token>s&rt=%<token>s",
    "a nested rt key" => "ri=us&tag=b&tag=a&rt=%<token>s&rt%%5Bx%%5D=1",
    "a duplicated reserved parameter" => "ri=us&tag=b&tag=a&next=%%2Fevil&next=%%2Fevil&rt=%<token>s",
  }.each do |label, query_format|
    test "a Jump-signed return with #{label} is rejected" do
      origin = "https://auth.umaxica.org"
      token = sign_return_token(aud: origin, src: "https://www.umaxica.org", url: "#{origin}/sign/in?ri=us&tag=b&tag=a")
      prime_jump_jwks_cache
      host! "auth.umaxica.org"
      https!
      get "/sign/in?#{format(query_format, token: token)}"

      assert_response :bad_request
    end
  end

  test "a request whose only return token key is nested is rejected before the normal flow" do
    host! "auth.umaxica.org"
    https!
    get "/sign/in?rt%5B%5D=a.b.c"

    assert_response :bad_request
  end

  test "sign app includes jump return verification" do
    assert_includes Auth::App::ApplicationController.ancestors, JumpRtReturnVerification
  end

  test "Auth org rejects invalid returns before its normal sign in" do
    org_origin = JumpRtSurface.issuer_origin("AUTH_ORG")
    get "#{org_origin}/sign/in", params: { rt: "not-a-jwt" }

    assert_response :bad_request
  end

  test "Auth org verifies an external Base return and cleans the token" do
    origin = JumpRtSurface.issuer_origin("AUTH_ORG")
    token = sign_return_token(
      aud: origin,
      src: JumpRtSurface.return_origin("BASE_ORG"),
      url: "#{origin}/sign/in?ri=us&ok=1",
    )
    prime_jump_jwks_cache
    get "#{origin}/sign/in", params: { ri: "us", ok: "1", rt: token }

    assert_response :see_other
    assert_equal "#{origin}/sign/in?ri=us&ok=1", response.location
    assert_match(/no-store/, response.headers.fetch("Cache-Control"))
  end

  test "Auth app consumes valid Base RP return and strips it from the sign in url" do
    sign_origin = auth_app_origin
    https!
    token = sign_return_token(
      aud: sign_origin,
      src: JumpRtSurface.return_origin("BASE_APP"),
      url: "#{sign_origin}/sign/in?ok=1",
    )

    prime_jump_jwks_cache
    get "#{sign_origin}/sign/in", params: { ok: "1", rt: token }

    assert_response :see_other
    assert_equal "#{sign_origin}/sign/in?ok=1", response.location
  end

  test "sign app rejects invalid jump return rt before normal auth flow" do
    sign_origin = auth_app_origin
    https!

    get "#{sign_origin}/sign/in", params: { rt: "not-a-jwt" }

    assert_response :bad_request
  end

  test "sign app runs jump return verification before set_current_context" do
    before_filters =
      Auth::App::ApplicationController._process_action_callbacks.filter_map do |callback|
        callback.filter if callback.kind == :before
      end

    assert_includes before_filters, :verify_jump_return_rt!
    assert_operator before_filters.index(:verify_jump_return_rt!), :<, before_filters.index(:set_current_context)
  end

  test "return verification concern does not register callbacks when included" do
    controller =
      Class.new(ActionController::Base) do # rubocop:disable Rails/ApplicationController
        include JumpRtReturnVerification
      end

    before_filters =
      controller._process_action_callbacks.filter_map do |callback|
        callback.filter if callback.kind == :before
      end

    assert_not_includes before_filters, :verify_jump_return_rt!
  end

  test "the retired Core app root is not routed" do
    core_host = ENV.fetch("PUBLIC_CORE_SERVICE_URL")
    route = Rails.application.routes.recognize_path("https://#{core_host}/", method: :get)

    assert_equal "unknown_hosts", route.fetch(:controller)
    assert_equal "show", route.fetch(:action)
  end

  private

  def stubbed_jump_location(rails_rt)
    rails_issuer = JumpRtSurface.issuer_origin("VISA_APP")
    payload, header = JWT.decode(
      rails_rt,
      JWT::JWK.import(@rails_public_jwk).public_key,
      true,
      algorithms: ["ES384"],
      iss: rails_issuer,
      verify_iss: true,
      aud: "https://jump.umaxica.net",
      verify_aud: true,
      verify_iat: false,
      verify_expiration: false,
      verify_not_before: false,
    )

    assert_equal "JWT", header.fetch("typ")
    assert_equal "auth-app-test", header.fetch("kid")
    assert_equal rails_issuer, payload.fetch("iss")
    assert_equal 1, payload.fetch("schema")
    assert_equal "jump-redirect", payload.fetch("sub")
    assert_equal "internal", payload.fetch("dst")
    assert_equal "reuse", payload.fetch("rpl")
    assert_equal "#{auth_app_origin}/sign/in", payload.fetch("url")

    return_rt = sign_return_token(
      aud: auth_app_origin,
      src: payload.fetch("iss"),
      url: payload.fetch("url"),
      jti: "jump-jti",
      iat: @now.to_i,
      nbf: @now.to_i,
      exp: @now.to_i + 30,
    )
    "#{auth_app_origin}/sign/in?#{Rack::Utils.build_query(rt: return_rt)}"
  end

  def prime_jump_jwks_cache
    jwks_url = "https://jump.umaxica.net/.well-known/jwks.json"
    cache_key = "jump_rt:return_jwks:#{Digest::SHA256.hexdigest(jwks_url)}"
    Rails.cache.write(cache_key, { "keys" => [@jump_public_jwk] }, expires_in: 30.seconds)
  end

  def sign_return_token(overrides = {})
    iat = @now.to_i
    payload = {
      schema: 1,
      iss: "https://jump.umaxica.net",
      aud: "https://www.app.localhost",
      sub: "jump-redirect",
      iat: iat,
      nbf: iat,
      exp: iat + 30,
      jti: "jump-return-jti",
      src: JumpRtSurface.issuer_origin("AUTH_APP"),
      dst: "internal",
      rpl: "reuse",
      url: "https://www.app.localhost/",
    }.merge(overrides)

    JWT.encode(payload, @jump_private_key, "ES384", { typ: "JWT", kid: "jump-test" })
  end

  def auth_app_origin
    JumpRtSurface.issuer_origin("AUTH_APP")
  end
end
