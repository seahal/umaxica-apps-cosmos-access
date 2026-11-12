# frozen_string_literal: true

require "test_helper"

class OpGrantRootReferenceShapeTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "grant issuer roots are immutable scalar history references rather than associations" do
    associations = {
      OpAppGrant => :client_token,
      OpOrgGrant => :operator_token,
      ClientToken => :op_app_grants,
      OperatorToken => :op_org_grants,
    }

    assert_equal associations.keys.map { |model| [model, nil] },
                 associations.map { |model, name| [model, model.reflect_on_association(name)] }
  end
end
