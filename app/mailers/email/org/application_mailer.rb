# typed: false
# frozen_string_literal: true

module Email::Org
  class ApplicationMailer < ActionMailer::Base

    default from: Rails.app.creds.option(:smtp_from_address_org, default: "from@umaxica.org")
  end
end
