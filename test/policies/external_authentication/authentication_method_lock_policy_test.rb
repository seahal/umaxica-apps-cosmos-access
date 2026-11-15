# frozen_string_literal: true

require "test_helper"

class ExternalAuthentication::AuthenticationMethodLockPolicyTest < ActiveSupport::TestCase
  test "delegates the exact principal and authentication method to the enforcement authority" do
    calls = []
    authority = Object.new
    authority.define_singleton_method(:authentication_method_effect_blocking?) do |principal_public_id,
                                                                                authentication_method|
      calls << [principal_public_id, authentication_method]
      authentication_method == "passkey"
    end
    policy = ExternalAuthentication::AuthenticationMethodLockPolicy.new

    assert policy.locked?(
      enforcement_case_class: authority,
      principal_public_id: "principal-ref",
      authentication_method: "passkey",
    )
    assert_not policy.locked?(
      enforcement_case_class: authority,
      principal_public_id: "principal-ref",
      authentication_method: "email",
    )
    assert_equal [
      ["principal-ref", "passkey"],
      ["principal-ref", "email"],
    ], calls
  end
end
