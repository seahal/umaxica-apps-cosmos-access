# frozen_string_literal: true

require "test_helper"

class OtpIssuanceNotifierPublicContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "each notifier fixes its delivery surface and refuses a missing recipient" do
    {
      Notify::App::OtpNotifier => "app",
      Notify::Org::OtpNotifier => "org",
    }.each do |notifier, surface|
      assert_equal surface, notifier.otp_delivery_surface
      error =
        assert_raises(ArgumentError) do
          notifier.issue(record: nil, otp_code: "123456")
        end
      assert_includes error.message, "record is required"
    end
  end
end
