# frozen_string_literal: true

require "test_helper"

class ActorValuesContextVisitorPredicateTest < ActiveSupport::TestCase
  test "retired visitor actor type is rejected while client and operator roles remain explicit" do
    empty = ActorValuesContext.empty
    client = empty.with(actor_type: :client)
    operator = empty.with(actor_type: :operator)

    assert_raises(ArgumentError) { empty.with(actor_type: :visitor) }
    assert_predicate empty, :anonymous?
    assert_predicate empty, :unauthenticated?
    assert_predicate client, :client?
    assert_predicate operator, :operator?
    assert_not_predicate client, :anonymous?
    assert_not_predicate operator, :anonymous?
  end
end
