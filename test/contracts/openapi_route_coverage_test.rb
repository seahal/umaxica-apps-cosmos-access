# frozen_string_literal: true

require "test_helper"
require_relative "../support/openapi_contract"

class OpenapiRouteCoverageTest < ActiveSupport::TestCase
  SURFACES = OpenapiContract::SURFACES
  DESCRIBED_PREFIXES = %r{\A/(api/v0|health)(/|\z)}
  TEXT_ONLY_PATHS = ["/health", "/health/startup", "/health/liveness", "/health/readiness"].freeze
  SENSITIVE_ADMISSION_PROTOCOL_PATHS = %r{\A/api/v0/sensitive_admission(?:s|_session|_confirmation)(?:/|\z)}

  test "every described surface has a bundled description that parses" do
    SURFACES.each do |surface|
      path = OpenapiContract.schema_path(surface)

      assert_path_exists path
      driver = Committee::Drivers.load_from_file(path, parser_options: { strict_reference_validation: true })

      assert_kind_of Committee::Drivers::OpenAPI3::Schema, driver
    end
  end

  test "no Auth or Visa route is missing from its surface description" do
    SURFACES.each do |surface|
      assert_empty routed_operations(surface) - described_operations(surface),
                   "#{surface} routes an operation missing from openapi/#{surface}.yml"
    end
  end

  test "no surface description contains an unrouted Auth or Visa operation" do
    SURFACES.each do |surface|
      assert_empty described_operations(surface) - routed_operations(surface),
                   "openapi/#{surface}.yml describes an operation that Auth and Visa do not route"
    end
  end

  private

  def routed_operations(surface)
    controller_pattern = %r{\A(?:auth|visa)/#{Regexp.escape(surface)}(?:/|\z)}

    Rails.application.routes.routes.filter_map do |route|
      next unless route.defaults[:controller].to_s.match?(controller_pattern)

      path = route.path.spec.to_s.sub(/\(\.:format\)\z/, "")
      next unless path.match?(DESCRIBED_PREFIXES)
      next if TEXT_ONLY_PATHS.include?(path)
      # These are Visa's browser-bound OP admission protocol, covered by its dedicated boundary tests.
      next if path.match?(SENSITIVE_ADMISSION_PROTOCOL_PATHS)

      verb = route.verb.to_s
      next if verb.empty?

      "#{verb} #{path.gsub(/:(\w+)/) { "{#{Regexp.last_match(1)}}" }}"
    end.to_set
  end

  def described_operations(surface)
    document = YAML.safe_load_file(OpenapiContract.schema_path(surface), aliases: true)

    document.fetch("paths").flat_map do |path, item|
      item.keys.grep(/\A(get|put|post|delete|patch|head|options|trace)\z/).map do |method|
        "#{method.upcase} #{path}"
      end
    end.to_set
  end
end
