# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch16ZerosAndPrecisionTest < ActiveSupport::TestCase
  test "webauthn surface not declared" do
    h = Class.new(ApplicationController) { include WebauthnSurfaceDeclarable }.new
    h.class.define_singleton_method(:declared_webauthn_surface_key) { nil }
    assert_raises(WebauthnSurfaceDeclarable::SurfaceNotDeclaredError) { h.webauthn_surface }
  end
end
