# typed: false
# frozen_string_literal: true

require "test_helper"

# Focused arms that close the remaining ~0.5-1.2 branch points to the 90% floor.
# Prefer calling real methods; stubs only fill collaborators.
class BranchCoverageBatch37ThresholdCloseTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "Webauthn AuthenticatorMetadata nil resolution safe navigation then arms" do
    context = Object.new
    %i(
      aaguid transports backup_eligible backup_state authenticator_attachment
    ).each do |m|
      context.define_singleton_method(m) { nil }
    end
    Webauthn::AuthenticatorNameResolver.stub(:resolve, nil) do
      result = Webauthn::AuthenticatorMetadata.attributes_from(context)

      assert_nil result[:provider_name]
      assert_nil result[:metadata_source]
    end
  end
end
