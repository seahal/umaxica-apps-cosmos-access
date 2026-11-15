# frozen_string_literal: true

require "test_helper"

class SignInActivationCandidateResolverTest < ActiveSupport::TestCase
  CandidateActor = Struct.new(:marker)

  test "an actor produces the default region and actor type candidate" do
    actor = CandidateActor.new
    cycle = Struct.new(:principal).new(nil)
    Actor.install_context!(preferences: Actor::Preference.new(region: "ca"))

    candidates = SignInActivationCandidateResolver.new(cycle: cycle, actor: actor).candidates

    assert_equal 1, candidates.length
    assert_equal "ca", candidates.first.region
    assert_equal actor.class.name, candidates.first.persona
  ensure
    Actor.clear
  end

  test "no resolved actor produces no activation candidates" do
    cycle = Struct.new(:principal).new(nil)

    assert_empty SignInActivationCandidateResolver.new(cycle: cycle, actor: nil).candidates
  end
end
