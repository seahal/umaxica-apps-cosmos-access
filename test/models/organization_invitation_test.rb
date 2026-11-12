# frozen_string_literal: true

require "test_helper"

class OrganizationInvitationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "new invitations require Governance authority without persisting a local replacement" do
    assert_no_difference "OrganizationInvitation.count" do
      assert_raises(GovernanceLookupUnavailableError) do
        OrganizationInvitation.create!(
          invited_by_id: 9_876_543, organization_id: 9_876_544, email: "invitee@example.test",
        )
      end
    end
  end

  test "historical invitation metadata remains usable while active consumption requires Governance" do
    now = OrganizationInvitation.database_now
    inserted = OrganizationInvitation.insert_all!(
      [{
        code: "h" * 32,
        email: "invitee@example.test",
        invited_by_id: 9_876_543,
        organization_id: 9_876_544,
        expires_at: now + 1.day,
        created_at: now,
        updated_at: now,
      }],
    )
    invitation = OrganizationInvitation.find(inserted.rows.first.first)
    invitation.update!(expires_at: now + 2.days)
    before = invitation.attributes

    assert_predicate invitation, :active?
    assert_equal invitation, OrganizationInvitation.find_valid(invitation.code, email: "INVITEE@example.test")
    assert_raises(GovernanceLookupUnavailableError) { invitation.consume! }
    assert_equal before, invitation.reload.attributes
    assert_equal 9_876_543, invitation.invited_by_id
    assert_equal 9_876_544, invitation.organization_id
    # The historical scalar has no deleted Operator ORM dependency.
    assert_nil OrganizationInvitation.reflect_on_association(:invited_by)
  end
end
