# frozen_string_literal: true

require "test_helper"

class BrowserAccessTokenSubjectTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "access JWT encodes an explicit numeric browser subject without actor inference" do
    host = OidcIssuer.host_for_resource_type("client")
    options = { host: host,
                resource_type: "client",
                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"), }
    token = SecurityJwtAuthAccessTokenCodec.encode(
      nil, **options, subject: "123", session_public_id: "browser-session", oidc_jti: SecureRandom.uuid,
    )

    assert_predicate token, :present?
    assert_equal "123", SecurityJwtAuthAccessTokenCodec.decode(token, **options).fetch("sub")
    [nil, "", " ", 123].each do |invalid|
      assert_nil SecurityJwtAuthAccessTokenCodec.encode(nil, **options, subject: invalid)
    end
  end
end
