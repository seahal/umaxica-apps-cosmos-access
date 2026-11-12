# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcSubjectTest < ActiveSupport::TestCase
  test "uses prefixed public subject instead of database id" do
    client = OpenStruct.new(public_id: "client-reference")

    assert_equal "cli_#{client.public_id}", OidcSubject.for(client, resource_type: "client")
    assert_equal client.public_id, OidcSubject.public_id_from("cli_#{client.public_id}", resource_type: "client")
  end

  test "uses separate prefixes for each actor type" do
    assert_equal "opr", OidcSubject.prefix_for("operator")
    assert_equal "cli", OidcSubject.prefix_for("client")
  end

  test "uses oidc_subject when resource provides it" do
    resource = OpenStruct.new(oidc_subject: "custom-oidc-id", public_id: "cli_abc123")

    assert_equal "cli_custom-oidc-id", OidcSubject.for(resource, resource_type: "client")
  end

  test "raises when resource lacks both oidc_subject and public_id" do
    resource = OpenStruct.new

    assert_raises(ArgumentError) { OidcSubject.for(resource, resource_type: "client") }
  end

  test "uses an explicit operator realm" do
    operator = OpenStruct.new(public_id: "opr_xyz")

    assert_equal "opr_#{operator.public_id}", OidcSubject.for(operator, resource_type: "operator")
  end

  test "rejects a missing realm even when the resource has a public ID" do
    unknown = OpenStruct.new(public_id: "custom_001")

    assert_raises(ArgumentError) { OidcSubject.for(unknown) }
  end
end
