# frozen_string_literal: true

require "test_helper"

class GovernanceSharedPathsUnavailableTest < ActiveSupport::TestCase
  test "existing real email challenge cannot resolve a retired contact and does not change session" do
    session, = ClientAuthCeremonySession.issue!
    context = {
      "version" => 1,
      "generation" => SecureRandom.uuid,
      "surface" => "app",
      "purpose" => "authentication",
      "sid_digest" => "a" * 64,
      "parent_kind" => "authorization",
      "parent_ref" => "parent",
      "mode" => "real",
      "contact_ref" => "retired-contact",
      "owner_ref" => "owner",
      "destination_digest" => "b" * 64,
      "binding_fact" => "fact",
      "code_digest" => "c" * 64,
      "issued_at" => Time.current.iso8601,
      "expires_at" => 5.minutes.from_now.iso8601,
      "verified_at" => nil,
      "result_expires_at" => nil,
    }
    session.update_column(:email_otp_context, context)
    before = session.reload.attributes

    assert_raises(GovernanceLookupUnavailableError) { session.verify_email_otp!(code: "123456") }
    assert_equal before, session.reload.attributes
  end

  test "OIDC resolver rejects inferred actor realm explicitly" do
    client = OidcClientRegistry.find!("core-app-jp")
    assert_raises(GovernanceLookupUnavailableError) do
      OidcAuthorizeRequestResolver.call(
        params: { client_id: client.client_id, redirect_uri: client.redirect_uris.first }, resource: Object.new,
      )
    end
  end

  test "OIDC resolver retains explicitly selected APP and ORG realm validation" do
    { "core-app-jp" => "client", "core-org-jp" => "operator" }.each do |client_id, resource_type|
      client = OidcClientRegistry.find!(client_id)
      error =
        assert_raises(OidcAuthorizeRequestResolver::RequestError) do
          OidcAuthorizeRequestResolver.call(
            params: { client_id: client_id, redirect_uri: client.redirect_uris.first },
            resource: Object.new, resource_type: resource_type,
          )
        end
      assert_equal "invalid_request", error.error
    end
  end
end
