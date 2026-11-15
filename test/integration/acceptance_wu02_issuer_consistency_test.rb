# frozen_string_literal: true

require "test_helper"

class AcceptanceWu02IssuerConsistencyTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  test "A02-4: discovery, ID Token, authorization response and Logout Token agree per realm" do
    realms = [
      ["client", "app", ClientToken, OpAppGrant, OpAppAuthorityStopParticipant, :client_token_id],
      ["operator", "org", OperatorToken, OpOrgGrant, OpOrgAuthorityStopParticipant, :operator_token_id],
    ]
    realms.each do |resource_type, realm, root_class, grant_class, participant_class, root_key|
      client = OidcClientRegistry.find!("core-#{realm}-jp")
      root = root_class.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
      root.update!(authentication_context: "normal") if resource_type == "operator"
      grant = grant_class.create!(
        :authentication_epoch => root.authentication_epoch, root_key => root.id, :oidc_client_id => client.client_id,
        :oidc_scope => "openid", :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
        :refresh_token_expires_at => 1.hour.from_now,
      )
      issuer = OidcDiscoveryDocument.for_resource_type(resource_type).fetch(:issuer)
      token = OidcIdTokenIssuer.call(
        resource_type: resource_type, client: client, nonce: grant.oidc_nonce, sid: grant.public_id,
        issuer: issuer, subject: "#{OidcSubject.prefix_for(resource_type)}_#{root.device_session.subject_public_id}",
      )
      id_claims, id_header = decode_op_id_token_for_test(token, resource_type:)

      assert_equal "id-token+jwt", id_header.fetch("typ"), realm
      assert_equal "PS256", id_header.fetch("alg"), realm
      assert_equal issuer, id_claims.fetch("iss"), realm
      assert_equal grant.oidc_nonce, id_claims.fetch("nonce"), realm
      callback = OidcAuthorizeCoordinator.error_redirect_url(
        redirect_uri: client.redirect_uris_by_realm.fetch(resource_type).first,
        resource_type: resource_type, error: "access_denied", state: "state",
      )

      assert_equal issuer, Rack::Utils.parse_nested_query(URI.parse(callback).query).fetch("iss"), realm
      success_callback = OidcAuthorizeCoordinator.rp_redirect_url(
        redirect_uri: client.redirect_uris_by_realm.fetch(resource_type).first, resource_type: resource_type,
        response_params: [["code", "test-code"], ["state", "state"]],
      )

      assert_equal issuer, Rack::Utils.parse_nested_query(URI.parse(success_callback).query).fetch("iss"), realm
      OpAuthorityStopCommitter.stop_root(
        root: root, cause: "browser_logout", principal_public_id: root.device_session.subject_public_id,
        authority_evidence_ref: "a02-4",
      )
      participant = participant_class.find_by!(grant_id: grant.id)
      logout_token = OpLogoutTokenIssuer.call(participant: participant, realm: realm)
      issuer_id = OidcIssuer.jwt_issuer_id_for_resource_type(resource_type)
      published_jwks = JitSecurityJwtRegistry.jwks_for(issuer_id)
      logout_header = JitSecurityJwtKeyring.parse_header(logout_token)
      signing_jwk = published_jwks.fetch(:keys).find { |jwk| jwk.fetch("kid") == logout_header.fetch("kid") }
      logout_claims, verified_header = JWT.decode(
        logout_token, JitSecurityJwtJwk.import_public_key(signing_jwk), true, { algorithms: ["PS256"] },
      )

      assert_equal "PS256", logout_header.fetch("alg"), realm
      assert_equal "logout+jwt", verified_header.fetch("typ"), realm
      assert_equal issuer, logout_claims.fetch("iss"), realm
      assert_equal [client.client_id], logout_claims.fetch("aud"), realm
      assert_equal grant.public_id, logout_claims.fetch("sid"), realm
      assert_equal({ OpLogoutTokenIssuer::EVENT => {} }, logout_claims.fetch("events"), realm)
      assert_not logout_claims.key?("nonce"), realm
    end
  end
end
