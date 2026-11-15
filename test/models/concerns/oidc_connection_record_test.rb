# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcConnectionRecordTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens client_device_sessions operator_tokens operator_device_sessions)

  setup do
    @client_root = client_tokens(:one)
    @operator_root = operator_tokens(:one)
  end

  test "status helpers classify active and revoked connections" do
    active = ClientOidcConnection.create!(subject_public_id: @client_root.subject_public_id, client_id: "core-app-jp")
    revoked = ClientOidcConnection.create!(
      subject_public_id: @client_root.subject_public_id,
      client_id: "warp-app-jp",
      revoked_at: Time.current,
    )

    assert_predicate active, :active?
    assert_not_predicate active, :revoked?
    assert_equal "active", active.status

    assert_predicate revoked, :revoked?
    assert_not_predicate revoked, :active?
    assert_equal "revoked", revoked.status
  end

  test "scopes returns nonblank scope tokens" do
    connection = ClientOidcConnection.new(scope: "openid  profile   email")

    assert_equal %w(openid profile email), connection.scopes
  end

  test "rp metadata uses registered client and falls back for unknown client" do
    registered = ClientOidcConnection.new(client_id: "core-app-jp")
    unknown = ClientOidcConnection.new(client_id: "unknown-client")

    assert_equal OidcClientRegistry.find!("core-app-jp").name, registered.rp_name
    assert_predicate registered.rp_domains, :any?
    assert_equal registered.rp_domains.join(", "), registered.rp_domain_text

    assert_nil unknown.rp_client
    assert_equal "unknown-client", unknown.rp_name
    assert_empty unknown.rp_domains
    assert_equal "-", unknown.rp_domain_text
  end

  test "connected_at mirrors created_at" do
    now = Time.current.change(usec: 0)
    connection = ClientOidcConnection.new(created_at: now)

    assert_equal now, connection.connected_at
  end

  test "each OIDC connection selects its actor's realm key" do
    assert_equal :user_id, ClientOidcConnection.actor_foreign_key
    assert_equal :staff_id, OperatorOidcConnection.actor_foreign_key
  end

  test "active scope excludes revoked connections" do
    active = ClientOidcConnection.create!(subject_public_id: @client_root.subject_public_id, client_id: "core-app-jp")
    revoked = ClientOidcConnection.create!(
      subject_public_id: @client_root.subject_public_id,
      client_id: "warp-app-jp",
      revoked_at: Time.current,
    )

    active_connections = ClientOidcConnection.active.to_a

    assert_includes active_connections, active
    assert_not_includes active_connections, revoked
  end

  test "active_tokens delegates to the surface token inventory" do
    client_connection = ClientOidcConnection.create!(subject_public_id: @client_root.subject_public_id, client_id: "core-app-jp")
    operator_connection = OperatorOidcConnection.create!(subject_public_id: @operator_root.subject_public_id, client_id: "core-org-jp")
    @client_root.update!(oidc_connection: client_connection)
    @operator_root.update!(oidc_connection: operator_connection)

    assert_equal [@client_root], client_connection.active_tokens
    assert_equal [@operator_root], operator_connection.active_tokens
  end

  test "including class must define actor foreign key" do
    model_class =
      Class.new(ApplicationRecord) do
        self.table_name = "client_oidc_connections"
        include OidcConnectionRecord
      end

    error = assert_raises(NotImplementedError) { model_class.actor_foreign_key }

    assert_match "must define actor_foreign_key", error.message
  end
end
