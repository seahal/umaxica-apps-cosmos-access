# typed: false
# frozen_string_literal: true

class OrgRegistrationPolicy
  def self.allowed?(invitation_code:, email: nil)
    new(invitation_code: invitation_code, email: email).allowed?
  end

  def self.validate!(invitation_code:, email: nil)
    new(invitation_code: invitation_code, email: email).validate!
  end

  def initialize(invitation_code:, email: nil)
    @invitation_code = invitation_code.to_s.downcase.strip
    @email = email.to_s.downcase.strip.presence
  end

  public

  def allowed?
    false
  end

  def validate!
    raise GovernanceLookupUnavailableError, OrgInvitationService::MIGRATION_REQUIRED_MESSAGE
  end

  def consume!
    validate!
  end
  public_class_method :allowed?, :validate!
end
