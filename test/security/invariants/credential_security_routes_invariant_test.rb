# typed: false
# frozen_string_literal: true

require "test_helper"

class CredentialSecurityRoutesInvariantTest < ActiveSupport::TestCase
  SECURITY_CONTROLLER_GLOBS = [
    "app/controllers/auth/*/verification/**/*_controller.rb",
  ].freeze

  test "production Auth verification controllers do not expose not implemented responses" do
    offenders =
      SECURITY_CONTROLLER_GLOBS.flat_map { |glob| Rails.root.glob(glob) }
        .select { |path| File.read(path).include?("head(:not_implemented)") }

    assert_empty offenders.map { |path| path.delete_prefix("#{Rails.root.join}") }
  end

  test "app Secret uses Client ownership and fact timestamps without a kind or status axis" do
    credential = ClientSecretCredential.new

    assert_not credential.available_at?(at: Client.database_now)
    assert_equal "Client", ClientSecretCredential.reflect_on_association(:client).class_name
    %w(user_secret_kind_id user_secret_status_id user_identity_secret_status_id secret_kind usage_policy
       max_uses uses_remaining use_count).each do |column|
      assert_not_includes ClientSecretCredential.column_names, column
    end
  end

  test "legacy permanent secret credentials expose no sign-in eligibility interface" do
    models = [
      [OperatorSecretCredential, OperatorSecretCredentialKind],
    ]

    models.each do |credential_class, kind_class|
      assert_not credential_class.respond_to?(:allowed_for_secret_credential_sign_in)
      assert_not credential_class.const_defined?(:SIGN_IN_ALLOWED_KIND_IDS, false)
      assert_not credential_class.const_defined?(:SIGN_IN_ALLOWED_STATUS_IDS, false)
      assert_not credential_class.new.respond_to?(:verify_for_secret_credential_sign_in!)
      assert_not credential_class.new.respond_to?(:usable_for_secret_credential_sign_in?)
      assert_not credential_class.new.respond_to?(:verify_and_consume!)
      assert_not credential_class.new.respond_to?(:permanent_secret_credential?)
      assert_not kind_class.const_defined?(:PERMANENT, false)
      assert_not kind_class.const_defined?(:ALLOWED_FOR_SECRET_SIGN_IN, false)
    end

    assert_equal 2, OperatorSecretCredentialKind::LOGIN
  end
end
