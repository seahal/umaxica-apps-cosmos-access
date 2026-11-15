# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationLinkAndUnlinkResultTest < ActiveSupport::TestCase
  test "linked results require both records and report the linked outcome" do
    result = ExternalAuthentication::LinkResult.new(status: :linked, user: Object.new, identity: Object.new)

    assert_predicate result, :linked?
    assert_raises(ArgumentError) do
      ExternalAuthentication::LinkResult.new(status: :linked, user: nil, identity: Object.new)
    end
    assert_raises(ArgumentError) do
      ExternalAuthentication::LinkResult.new(status: :other, user: Object.new, identity: Object.new)
    end
  end

  test "unlink results distinguish an unlink from an already absent identity" do
    unlinked = ExternalAuthentication::UnlinkResult.new(status: :unlinked, provider: "google")
    already_unlinked = ExternalAuthentication::UnlinkResult.new(status: :already_unlinked, provider: "apple")

    assert_predicate unlinked, :unlinked?
    assert_not_predicate unlinked, :already_unlinked?
    assert_predicate already_unlinked, :already_unlinked?
    assert_not_predicate already_unlinked, :unlinked?
    assert_raises(ArgumentError) do
      ExternalAuthentication::UnlinkResult.new(status: :unlinked, provider: "unknown")
    end
  end
end
