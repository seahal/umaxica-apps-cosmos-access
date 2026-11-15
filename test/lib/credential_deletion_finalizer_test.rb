# frozen_string_literal: true

require "test_helper"

class CredentialDeletionFinalizerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "register retains cookie identity options and omits request-only attributes" do
    env = {}
    options = {
      domain: "auth.example.test",
      expires: Time.zone.local(2030, 1, 1),
      max_age: 60,
      value: "credential-secret",
      path: "/auth",
      httponly: true,
      secure: true,
      same_site: :lax,
    }

    CredentialDeletionFinalizer.register(env, "auth_session", options)

    deletion = env.fetch(CredentialDeletionFinalizer::ENV_KEY).fetch("auth_session")

    assert_equal({ path: "/auth", httponly: true, secure: true, same_site: :lax }, deletion)
    assert_predicate deletion, :frozen?
    assert_not_includes deletion.inspect, "credential-secret"
  end

  test "register refuses a blank cookie name without recording a deletion" do
    env = {}

    assert_raises(ArgumentError) do
      CredentialDeletionFinalizer.register(env, " ", { path: "/auth" })
    end

    assert_empty env
  end
end
