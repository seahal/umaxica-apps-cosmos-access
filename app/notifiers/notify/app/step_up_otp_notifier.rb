# frozen_string_literal: true

class Notify::App::StepUpOtpNotifier < Notify::ApplicationNotifier
  extend Notify::StepUpOtpIssuanceNotifier

  deliver_by :email, class: "StepUpEmailDeliveryJob"

  public

  def deliver_step_up_email!(recipient:, **_arguments)
    raise GovernanceLookupUnavailableError, "Governance step-up email delivery is unavailable"
  end

  def self.step_up_email_model
    raise GovernanceLookupUnavailableError, "Governance step-up email delivery is unavailable"
  end
  private_class_method :step_up_email_model
end
