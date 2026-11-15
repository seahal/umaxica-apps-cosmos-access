# typed: false
# frozen_string_literal: true

require "test_helper"

class OutboundEmailSuspensionInterceptorTest < ActiveSupport::TestCase
  teardown do
    Flipper.disable(:outbound_email_suspended)
  end

  test "an unsuspended email channel leaves the message deliverable" do
    Flipper.disable(:outbound_email_suspended)
    message = Mail.new
    message.perform_deliveries = true

    OutboundEmailSuspensionInterceptor.delivering_email(message)

    assert message.perform_deliveries
  end

  test "a suspended email channel stops the message before delivery" do
    Flipper.enable(:outbound_email_suspended)
    message = Mail.new
    message.perform_deliveries = true

    OutboundEmailSuspensionInterceptor.delivering_email(message)

    assert_not message.perform_deliveries
  end
end
