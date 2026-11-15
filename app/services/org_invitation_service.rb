# typed: false
# frozen_string_literal: true

class OrgInvitationService
  MIGRATION_REQUIRED_MESSAGE = "Organization invitations are unavailable pending Bureau migration"

  Result =
    Data.define(:success, :invitation, :code, :error) do
      def success? = !!success
    end

  def self.create(organization_id:, email:, invited_by:, role_id: 0)
    unavailable_result
  end

  def self.validate(code:, email: nil)
    unavailable_result
  end

  def self.consume(code:, email: nil)
    unavailable_result
  end

  def self.unavailable_result
    Result.new(success: false, invitation: nil, code: nil, error: MIGRATION_REQUIRED_MESSAGE)
  end
  private_class_method :unavailable_result
  public_class_method :create, :validate, :consume
end
