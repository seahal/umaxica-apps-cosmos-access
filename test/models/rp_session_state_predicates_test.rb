# typed: false
# frozen_string_literal: true

require "test_helper"

class RpSessionStatePredicatesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  CALLBACK_STATE_CLASSES = [
    RpBaseAppCallbackState,
    RpBaseOrgCallbackState,
    RpCoreAppCallbackState,
    RpCoreOrgCallbackState,
    RpEditOrgCallbackState,
    RpPalmAppCallbackState,
    RpTechOrgCallbackState,
    RpWarpAppCallbackState,
    RpWarpOrgCallbackState,
  ].freeze

  SESSION_CLASSES = [
    RpBaseAppSession,
    RpBaseOrgSession,
    RpCoreAppSession,
    RpCoreOrgSession,
    RpEditOrgSession,
    RpPalmAppSession,
    RpTechOrgSession,
    RpWarpAppSession,
    RpWarpOrgSession,
  ].freeze

  test "each RP callback state reports whether it has been consumed" do
    CALLBACK_STATE_CLASSES.each do |model|
      assert_not model.new(consumed_at: nil).consumed?, "#{model} starts unconsumed"
      assert_predicate model.new(consumed_at: Time.current), :consumed?, "#{model} records consumption"
    end
  end

  test "each RP session rejects expired or revoked sessions without a parent binding" do
    now = Time.zone.parse("2026-11-05 12:00:00")

    SESSION_CLASSES.each do |model|
      expired = model.new(
        revoked_at: nil,
        op_session_binding_id: nil,
        absolute_expires_at: now,
      )
      revoked = model.new(
        revoked_at: now - 1.second,
        op_session_binding_id: 1,
        absolute_expires_at: now + 1.minute,
      )

      assert_not expired.active?(now:), "#{model} expires at the boundary"
      assert_not revoked.active?(now:), "#{model} refuses a revoked session"
    end
  end

  test "Base RP sessions query their isolated actor-selection records" do
    assert_not RpBaseAppSession.new(id: -1).selected_actor_context?
    assert_not RpBaseOrgSession.new(id: -1).selected_actor_context?
  end
end
