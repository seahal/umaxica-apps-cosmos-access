# frozen_string_literal: true

require "test_helper"

class VisaGovernanceRevocationCommandsControllerTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false
  self.fixture_table_names = []

  setup do
    @command_ids = []
  end

  teardown do
    # These UUIDs belong only to this disposable test's commands; no retained rows are selected.
    OpAppGovernanceRevocationReceipt.where(command_id: @command_ids).delete_all
    OpOrgGovernanceRevocationReceipt.where(command_id: @command_ids).delete_all
  end

  test "missing Governance trust configuration returns unavailable without selecting a substitute issuer" do
    [
      ["app", ENV.fetch("PUBLIC_VISA_SERVICE_URL")],
      ["org", ENV.fetch("PUBLIC_VISA_STAFF_URL")],
    ].each do |realm, host|
      host!(host)
      https!
      issuer_key = "GOVERNANCE_#{realm.upcase}_REVOCATION_ISSUER"
      jwks_key = "GOVERNANCE_#{realm.upcase}_REVOCATION_JWKS_URL"
      original = { issuer_key => ENV[issuer_key], jwks_key => ENV[jwks_key] }
      ENV.delete(issuer_key)

      post(
        "/api/v0/revocation_commands", params: "a.b.c",
                                       headers: {
                                         "CONTENT_TYPE" => "application/jwt",
                                         "Origin" => nil,
                                         "Sec-Fetch-Site" => nil,
                                       },
      )

      assert_response :service_unavailable
      assert_equal "application/problem+json", response.media_type

      ENV[issuer_key] = "https://governance.example"
      ENV.delete(jwks_key)

      post(
        "/api/v0/revocation_commands", params: "a.b.c",
                                       headers: {
                                         "CONTENT_TYPE" => "application/jwt",
                                         "Origin" => nil,
                                         "Sec-Fetch-Site" => nil,
                                       },
      )

      assert_response :service_unavailable
      assert_equal "application/problem+json", response.media_type
      assert_nil response.headers["Set-Cookie"]
    ensure
      original&.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
    end
  end

  test "each realm verifies Governance signatures and acknowledges only its committed command with an OP signature" do
    [
      ["app", "client", OpAppGovernanceRevocationReceipt, ENV.fetch("PUBLIC_VISA_SERVICE_URL"), "surface:VISA_APP"],
      ["org", "operator", OpOrgGovernanceRevocationReceipt, ENV.fetch("PUBLIC_VISA_STAFF_URL"), "surface:VISA_ORG"],
    ].each do |realm, resource_type, receipt_class, host, issuer_id|
      host!(host)
      https!
      key = OpenSSL::PKey::EC.generate("secp384r1")
      jwks = JSON.generate(keys: [JWT::JWK.new(key, "governance-key").export.merge(alg: "ES384", use: "sig")])
      issuer_key = "GOVERNANCE_#{realm.upcase}_REVOCATION_ISSUER"
      jwks_key = "GOVERNANCE_#{realm.upcase}_REVOCATION_JWKS_URL"
      original = { issuer_key => ENV[issuer_key], jwks_key => ENV[jwks_key] }
      ENV[issuer_key] = "https://governance.example"
      ENV[jwks_key] = "https://governance.example/keys"
      command_id = SecureRandom.uuid
      @command_ids << command_id
      prefix = (realm == "app") ? "cli" : "opr"
      payload = {
        "iss" => "https://governance.example",
        "aud" => OidcIssuer.for_resource_type(resource_type),
        "iat" => Time.current.to_i,
        "exp" => 60.seconds.from_now.to_i,
        "jti" => command_id,
        "realm" => realm,
        "sub" => "#{prefix}_#{PublicId.generate}",
        "scope" => "all_sessions",
        "actor" => "opr_operator",
        "reason" => "account_disabled",
      }
      token = JWT.encode(payload, key, "ES384", { kid: "governance-key", typ: "governance-revocation+jwt" })
      verifier = GovernanceRevocationCommandVerifier.new(
        issuer: payload.fetch("iss"), audience: payload.fetch("aud"), realm:,
        jwks_url: "https://governance.example/keys", fetcher: -> { JSON.parse(jwks) },
      )
      GovernanceRevocationCommandVerifier.stub(
        :new, lambda { |**options|
                assert_equal [payload.fetch("iss"), payload.fetch("aud"), realm, "https://governance.example/keys"],
                             options.values_at(:issuer, :audience, :realm, :jwks_url)
                verifier
              },
      ) do
        2.times do
          post(
            "/api/v0/revocation_commands", params: token,
                                           headers: {
                                             "CONTENT_TYPE" => "application/jwt",
                                             "Origin" => nil,
                                             "Sec-Fetch-Site" => nil,
                                           },
          )

          assert_response :ok
          assert_equal "application/jwt", response.media_type
          assert_includes response.headers.fetch("Cache-Control"), "no-store"
          assert_nil response.headers["Set-Cookie"]
          assert receipt_class.exists?(command_id:)
          assert_not receipt_class.lease_connection.transaction_open?
          header = JitSecurityJwtKeyring.parse_header(response.body)
          public_key = JitSecurityJwtKeyring.public_key_for(header.fetch("kid"), issuer_id:)
          acknowledgement, = JWT.decode(response.body, public_key, true, algorithms: ["PS256"])

          assert_equal "governance-revocation-ack+jwt", header.fetch("typ")
          assert_equal command_id, acknowledgement.fetch("command_id")
          assert_equal "completed", acknowledgement.fetch("status")
          assert_equal payload.fetch("aud"), acknowledgement.fetch("iss")
          assert_equal payload.fetch("iss"), acknowledgement.fetch("aud")
          assert_equal 1, receipt_class.where(command_id:).count
        end
        attacker_key = OpenSSL::PKey::EC.generate("secp384r1")
        forged = JWT.encode(payload, attacker_key, "ES384", { kid: "governance-key", typ: "governance-revocation+jwt" })
        post(
          "/api/v0/revocation_commands", params: forged,
                                         headers: {
                                           "CONTENT_TYPE" => "application/jwt",
                                           "Origin" => nil,
                                           "Sec-Fetch-Site" => nil,
                                         },
        )

        assert_response :unauthorized
        assert_equal "application/problem+json", response.media_type

        changed = JWT.encode(
          payload.merge("reason" => "different_reason"), key, "ES384",
          { kid: "governance-key", typ: "governance-revocation+jwt" },
        )
        post(
          "/api/v0/revocation_commands", params: changed,
                                         headers: {
                                           "CONTENT_TYPE" => "application/jwt",
                                           "Origin" => nil,
                                           "Sec-Fetch-Site" => nil,
                                         },
        )

        assert_response :bad_request
        assert_equal "application/problem+json", response.media_type
        assert_equal "account_disabled", receipt_class.find(command_id).command.fetch("reason")
        assert_equal 1, receipt_class.where(command_id:).count
      end
    ensure
      original&.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
    end
  end

  test "browser input and malformed bodies receive an explicit error without an acknowledgement" do
    [ENV.fetch("PUBLIC_VISA_SERVICE_URL"), ENV.fetch("PUBLIC_VISA_STAFF_URL")].each do |host|
      host! host
      https!
      [
        ["x", { "CONTENT_TYPE" => "application/jwt", "Origin" => "https://attacker.example", "Sec-Fetch-Site" => nil },
         :forbidden,],
        ["x", { "CONTENT_TYPE" => "application/jwt", "Origin" => nil, "Sec-Fetch-Site" => "cross-site" }, :forbidden],
        ["x", { "CONTENT_TYPE" => "text/plain", "Origin" => nil, "Sec-Fetch-Site" => nil }, :unsupported_media_type],
        ["x" * 8_193, { "CONTENT_TYPE" => "application/jwt", "Origin" => nil, "Sec-Fetch-Site" => nil },
         :content_too_large,],
      ].each do |body, headers, status|
        post("/api/v0/revocation_commands", params: body, headers:)

        assert_response status
        assert_equal "application/problem+json", response.media_type
        assert_includes response.headers.fetch("Cache-Control"), "no-store"
        assert_nil response.headers["Set-Cookie"]
        assert_not_includes response.body, body if body.length > 1
      end
    end
  end

  test "a failed Governance key fetch cannot revoke or acknowledge a command" do
    [
      ["app", "client", OpAppGovernanceRevocationReceipt, ENV.fetch("PUBLIC_VISA_SERVICE_URL")],
      ["org", "operator", OpOrgGovernanceRevocationReceipt, ENV.fetch("PUBLIC_VISA_STAFF_URL")],
    ].each do |realm, resource_type, receipt_class, host|
      host!(host)
      https!
      issuer_key = "GOVERNANCE_#{realm.upcase}_REVOCATION_ISSUER"
      jwks_key = "GOVERNANCE_#{realm.upcase}_REVOCATION_JWKS_URL"
      original = { issuer_key => ENV[issuer_key], jwks_key => ENV[jwks_key] }
      ENV[issuer_key] = "https://governance.example"
      ENV[jwks_key] = "https://governance.example/keys"
      command_id = SecureRandom.uuid
      @command_ids << command_id
      prefix = (realm == "app") ? "cli" : "opr"
      payload = {
        "iss" => "https://governance.example",
        "aud" => OidcIssuer.for_resource_type(resource_type),
        "iat" => Time.current.to_i,
        "exp" => 60.seconds.from_now.to_i,
        "jti" => command_id,
        "realm" => realm,
        "sub" => "#{prefix}_#{PublicId.generate}",
        "scope" => "all_sessions",
        "actor" => "opr_operator",
        "reason" => "account_disabled",
      }
      token = JWT.encode(
        payload, OpenSSL::PKey::EC.generate("secp384r1"), "ES384",
        { kid: "governance-key", typ: "governance-revocation+jwt" },
      )
      verifier = GovernanceRevocationCommandVerifier.new(
        issuer: payload.fetch("iss"), audience: payload.fetch("aud"), realm:,
        jwks_url: "https://governance.example/keys",
        fetcher: -> { raise GovernanceRevocationCommandVerifier::Unavailable, "test key fetch failed" },
      )
      GovernanceRevocationCommandVerifier.stub(:new, verifier) do
        post(
          "/api/v0/revocation_commands", params: token,
                                         headers: {
                                           "CONTENT_TYPE" => "application/jwt",
                                           "Origin" => nil,
                                           "Sec-Fetch-Site" => nil,
                                         },
        )

        assert_response :service_unavailable
        assert_equal "application/problem+json", response.media_type
        assert_not receipt_class.exists?(command_id:)
        assert_nil response.headers["Set-Cookie"]
      end
    ensure
      original&.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
    end
  end

  test "an outer uncommitted transaction cannot yield a completed acknowledgement" do
    [
      ["app", OpAppGovernanceRevocationReceipt, "client", ENV.fetch("PUBLIC_VISA_SERVICE_URL")],
      ["org", OpOrgGovernanceRevocationReceipt, "operator", ENV.fetch("PUBLIC_VISA_STAFF_URL")],
    ].each do |realm, receipt_class, resource_type, host|
      host!(host)
      https!
      key = OpenSSL::PKey::EC.generate("secp384r1")
      jwks = JSON.generate(keys: [JWT::JWK.new(key, "governance-key").export.merge(alg: "ES384", use: "sig")])
      fetched = 0
      issuer_key = "GOVERNANCE_#{realm.upcase}_REVOCATION_ISSUER"
      jwks_key = "GOVERNANCE_#{realm.upcase}_REVOCATION_JWKS_URL"
      original = { issuer_key => ENV[issuer_key], jwks_key => ENV[jwks_key] }
      ENV[issuer_key] = "https://governance.example"
      ENV[jwks_key] = "https://governance.example/keys"
      prefix = (realm == "app") ? "cli" : "opr"
      command_id = SecureRandom.uuid
      @command_ids << command_id
      payload = {
        "iss" => "https://governance.example",
        "aud" => OidcIssuer.for_resource_type(resource_type),
        "iat" => Time.current.to_i,
        "exp" => 60.seconds.from_now.to_i,
        "jti" => command_id,
        "realm" => realm,
        "sub" => "#{prefix}_#{PublicId.generate}",
        "scope" => "all_sessions",
        "actor" => "opr_operator",
        "reason" => "account_disabled",
      }
      token = JWT.encode(payload, key, "ES384", { kid: "governance-key", typ: "governance-revocation+jwt" })
      verifier = GovernanceRevocationCommandVerifier.new(
        issuer: payload.fetch("iss"), audience: payload.fetch("aud"), realm:,
        jwks_url: "https://governance.example/keys",
        fetcher: -> {
          fetched += 1
          JSON.parse(jwks)
        },
      )
      GovernanceRevocationCommandVerifier.stub(:new, verifier) do
        receipt_class.transaction do
          post(
            "/api/v0/revocation_commands", params: token,
                                           headers: {
                                             "CONTENT_TYPE" => "application/jwt",
                                             "Origin" => nil,
                                             "Sec-Fetch-Site" => nil,
                                           },
          )

          assert_response :service_unavailable
          assert_equal "application/problem+json", response.media_type
          assert_equal 1, fetched
          assert_not receipt_class.exists?(command_id:)
          raise ActiveRecord::Rollback
        end
      end

      assert_not receipt_class.exists?(command_id:)
    ensure
      original&.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
    end
  end
end
