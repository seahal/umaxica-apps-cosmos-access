# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class CookieSecurityInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      test "authentication cookies are host only and HttpOnly" do
        request = ActionDispatch::TestRequest.create("HTTP_HOST" => "id.app.example")

        options = CoreCookieOptions.for(
          request:, httponly: true, secure: true, same_site: :lax, path: "/",
        )

        assert options[:secure]
        assert options[:httponly]
        assert_equal :lax, options[:same_site]
        assert_equal "/", options[:path]
        assert_not options.key?(:domain)
      end
    end
  end
end
