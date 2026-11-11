# typed: false
# frozen_string_literal: true

module Email::App
  class ApplicationMailer < ActionMailer::Base

    default from: -> { ENV.fetch("SMTP_FROM_ADDRESS_APP") }
  end
end
