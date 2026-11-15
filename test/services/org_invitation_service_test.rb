# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgInvitationServiceTest < ActiveSupport::TestCase
  test "invitation issuance stays unavailable until Governance authority is migrated" do
    assert_no_difference "OrganizationInvitation.count" do
      result = OrgInvitationService.create(
        organization_id: 9_876_544,
        email: "invitee@example.test",
        invited_by: 9_876_543,
      )

      assert_not_predicate result, :success?
      assert_nil result.invitation
      assert_nil result.code
      assert_equal OrgInvitationService::MIGRATION_REQUIRED_MESSAGE, result.error
    end
  end

  test "validation and acceptance stay unavailable before any legacy invitation lookup" do
    invitation_lookup = ->(*) { flunk("legacy invitation lookup must not run before authority migration") }

    OrganizationInvitation.stub(:find_valid, invitation_lookup) do
      validation = OrgInvitationService.validate(code: "legacy-code", email: "invitee@example.test")

      assert_not_predicate validation, :success?
      assert_nil validation.invitation
      assert_nil validation.code
      assert_equal OrgInvitationService::MIGRATION_REQUIRED_MESSAGE, validation.error

      acceptance = OrgInvitationService.consume(code: "legacy-code", email: "invitee@example.test")

      assert_not_predicate acceptance, :success?
      assert_nil acceptance.invitation
      assert_nil acceptance.code
      assert_equal OrgInvitationService::MIGRATION_REQUIRED_MESSAGE, acceptance.error
    end
  end

  test "registration policy refuses every state without reading the legacy invitation record" do
    invitation_lookup = ->(*) { flunk("legacy invitation lookup must not run before authority migration") }

    OrganizationInvitation.stub(:find_valid, invitation_lookup) do
      OrganizationInvitation.stub(:find_by, invitation_lookup) do
        assert_not OrgRegistrationPolicy.allowed?(invitation_code: "legacy-code", email: "invitee@example.test")

        assert_raises(GovernanceLookupUnavailableError) do
          OrgRegistrationPolicy.validate!(invitation_code: "legacy-code", email: "invitee@example.test")
        end

        policy = OrgRegistrationPolicy.new(invitation_code: "legacy-code", email: "invitee@example.test")

        assert_not policy.allowed?
        assert_raises(GovernanceLookupUnavailableError) { policy.validate! }
        assert_raises(GovernanceLookupUnavailableError) { policy.consume! }
      end
    end
  end
end
