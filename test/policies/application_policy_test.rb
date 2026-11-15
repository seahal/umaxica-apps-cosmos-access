# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ApplicationPolicyTest < ActiveSupport::TestCase
  class TestRecord
    attr_reader :marker

    def initialize
      @marker = :test_record
    end
  end

  class RelationDouble
    attr_reader :none_called

    def none
      @none_called = true
      :none_scope
    end
  end

  class TestPolicy < ApplicationPolicy; end

  class OrganizationRecord
    attr_reader :organization

    def initialize(organization:)
      @organization = organization
    end
  end

  class OrganizationIdRecord
    attr_reader :organization_id

    def initialize(organization_id:)
      @organization_id = organization_id
    end
  end

  class LegacyRoleSubject
    def initialize(organization:)
      @organization = organization
    end

    def has_role?(role, organization:)
      role == "operator" && organization == @organization
    end

    def operator_or_manager?(organization:)
      organization == @organization
    end

    def can_edit?(organization:)
      organization == @organization
    end

    def can_view?(organization:)
      organization == @organization
    end

    def can_contribute?(organization:)
      organization == @organization
    end
  end

  class LegacyRolePolicy < ApplicationPolicy
    def show? = operator?

    def create? = operator_or_manager?

    def update? = can_edit?

    def destroy? = can_view?

    def index? = can_contribute?
  end

  def setup
    @user = nil
    @record = TestRecord.new
    @policy = TestPolicy.new(@record, user: @user)
  end

  # Default behavior tests
  def test_index_returns_false_by_default
    assert_not @policy.apply(:index?)
  end

  def test_show_returns_false_by_default
    assert_not @policy.apply(:show?)
  end

  def test_create_returns_false_by_default
    assert_not @policy.apply(:create?)
  end

  def test_new_delegates_to_create
    assert_equal @policy.apply(:create?), @policy.apply(:new?)
  end

  def test_update_returns_false_by_default
    assert_not @policy.apply(:update?)
  end

  def test_edit_delegates_to_update
    assert_equal @policy.apply(:update?), @policy.apply(:edit?)
  end

  def test_destroy_returns_false_by_default
    assert_not @policy.apply(:destroy?)
  end

  def test_relation_scope_denies_all_by_default
    relation = RelationDouble.new

    assert_equal :none_scope, @policy.apply_scope(relation, type: :active_record_relation)
    assert relation.none_called
  end

  # Attributes tests
  def test_user_attribute_is_accessible
    policy = ApplicationPolicy.new(@record, user: @user)

    assert_nil policy.user
  end

  def test_record_attribute_is_accessible
    policy = ApplicationPolicy.new(@record, user: @user)

    assert_equal @record, policy.record
  end

  def test_legacy_role_rules_preserve_organization_scope_for_policy_subclasses
    organization = Object.new
    other_organization = Object.new
    user = LegacyRoleSubject.new(organization: organization)

    policy = LegacyRolePolicy.new(OrganizationRecord.new(organization: organization), user: user)

    assert policy.apply(:show?)
    assert policy.apply(:create?)
    assert policy.apply(:update?)
    assert policy.apply(:destroy?)
    assert policy.apply(:index?)

    organization_id_policy =
      LegacyRolePolicy.new(
        OrganizationIdRecord.new(organization_id: 42), user: LegacyRoleSubject.new(organization: 42),
      )

    assert organization_id_policy.apply(:show?)

    other_policy = LegacyRolePolicy.new(OrganizationRecord.new(organization: other_organization), user: user)

    assert_not other_policy.apply(:show?)
    assert_not other_policy.apply(:create?)
    assert_not other_policy.apply(:update?)
    assert_not other_policy.apply(:destroy?)
    assert_not other_policy.apply(:index?)

    unscoped_policy = LegacyRolePolicy.new(@record, user: user)

    assert_not unscoped_policy.apply(:show?)
  end

  private
end
