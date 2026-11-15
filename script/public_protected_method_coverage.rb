# frozen_string_literal: true

require "json"

Rails.application.eager_load!
require "rubocop"
require Rails.root.join("lib/rubocop/cop/umaxica/no_concern_inclusion_hooks").to_s
require Rails.root.join("lib/rubocop/cop/umaxica/explicit_method_visibility").to_s
require Rails.root.join("lib/omniauth/strategies/umaxica_entra").to_s

ActiveSupport.deprecator.silenced = true
result_path = Rails.root.join("coverage/.resultset.json")
coverage_data = JSON.parse(File.read(result_path)).fetch("Rails Tests").fetch("coverage")
modules =
  ObjectSpace.each_object(Module).with_object({}) do |mod, result|
    constant_name = Module.instance_method(:name).bind_call(mod)
    result[constant_name] = mod if constant_name.present?
  end

# These runtime owners exist only to exercise Rails-generated concern behavior in tests; their
# included production methods are not application entry points.
test_only_owners = [
  "PublicMethodContractsTest::CoreRpBridgeRecord",
  "FlowBaseTest::MisconfiguredCycleBaseTestRecord",
  "Sign::WebauthnTest::TestController",
  "TargetedModelLineCoverageTest::AbstractOidcAuthorization",
]
test_only_anonymous_class_attribute_records = [
  [
    "app/controllers/concerns/webauthn_surface_declarable.rb",
    "declared_webauthn_surface_key?",
    20,
  ],
  [
    "app/controllers/concerns/webauthn_surface_declarable.rb",
    "declared_webauthn_surface_key",
    20,
  ],
  [
    "app/controllers/concerns/webauthn_surface_declarable.rb",
    "declared_webauthn_surface_key=",
    20,
  ],
]
public_records = []
private_records = []
test_only_records = []
unclassified = []

coverage_data.each do |path, details|
  next unless path.start_with?(Rails.root.join("app").to_s, Rails.root.join("lib").to_s)
  next unless File.file?(path)

  details.fetch("methods", {}).each do |key, calls|
    match = key.match(/\A\["(.+)", :(.+?), (\d+), \d+, \d+, \d+\]\z/)
    next unless match

    class_name, method_name, line = match.captures
    line = Integer(line)
    singleton_record = class_name.start_with?("#<Class:")
    lookup_name =
      if singleton_record
        class_name.delete_prefix("#<Class:").sub(/\(.*\)>\z/, "").delete_suffix(">")
      else
        class_name
      end
    if singleton_record
      duplicated_instance = class_name.match(/\A#<Class:#<(.+?):0x[0-9a-f]+>>\z/i)
      if duplicated_instance
        # OmniAuth duplicates its strategy instance per request. SimpleCov records that instance's
        # ordinary public method under the duplicate's singleton-class inspect string.
        lookup_name = duplicated_instance[1]
        singleton_record = false
      end
    end
    source_path = path.delete_prefix(Rails.root.to_s + "/")
    # branch_coverage_batch16 constructs an anonymous test controller; Rails attributes
    # its generated class methods to the concern's class_attribute declaration.
    test_only_anonymous_owner = class_name.match?(/\A#<Class:(?:#<Class:)?0x[0-9a-f]+/i)
    test_only_generated_class_attribute =
      test_only_anonymous_owner && test_only_anonymous_class_attribute_records.include?(
        [source_path, method_name, line],
      )
    if test_only_owners.include?(class_name) || test_only_owners.include?(lookup_name) ||
        test_only_generated_class_attribute
      test_only_records << [path, class_name, method_name, line, calls]
      next
    end

    method_symbol = method_name.to_sym
    if class_name.start_with?("#<Module:")
      # A test duplicates FqdnAvailabilityRegistry to inject a hostname collision. SimpleCov
      # attributes calls on that anonymous module to `#<Module:0x0>`; recover the named module
      # whose singleton method has this exact source location.
      matching_modules =
        modules.values.select do |candidate|
          candidate.singleton_class.ancestors.any? do |owner|
            names = [
              *owner.public_instance_methods(false),
              *owner.protected_instance_methods(false),
              *owner.private_instance_methods(false),
            ]
            next false unless names.include?(method_symbol)

            method_source, method_line = owner.instance_method(method_symbol).source_location
            File.expand_path(method_source.to_s) == File.expand_path(path) && method_line == line
          end
        end
      if matching_modules.one?
        lookup_name = matching_modules.first.name
        singleton_record = true
      end
    end

    mod = modules[lookup_name]
    unless mod
      unclassified << [path, class_name, method_name, line]
      next
    end

    visibility = nil
    owner_groups = []
    owner_groups << [mod.ancestors, "instance"] unless singleton_record
    owner_groups << [mod.singleton_class.ancestors, "singleton"]

    owner_groups.each do |owners, owner_kind|
      owners.each do |owner|
        candidates =
          if owner_kind == "instance"
            [
              ["public_instance", owner.public_instance_methods(false)],
              ["protected_instance", owner.protected_instance_methods(false)],
              ["private_instance", owner.private_instance_methods(false)],
            ]
          else
            [
              ["public_singleton", owner.public_instance_methods(false)],
              ["protected_singleton", owner.protected_instance_methods(false)],
              ["private_singleton", owner.private_instance_methods(false)],
            ]
          end

        candidates.each do |kind, names|
          next unless names.include?(method_symbol)

          method_object = owner.instance_method(method_symbol)
          source_path, source_line = method_object.source_location
          next unless File.expand_path(source_path.to_s) == File.expand_path(path) && source_line == line

          visibility = kind
          break
        end
        break if visibility
      end
      break if visibility
    end

    record = [visibility, source_path, class_name, method_name, line, calls]
    if visibility&.start_with?("public_", "protected_")
      public_records << record
    elsif visibility&.start_with?("private_")
      private_records << record
    else
      unclassified << [path, class_name, method_name, line]
    end
  end
end

unclassified.each { |record| warn "UNCLASSIFIED\t#{record.join("\t")}" }
abort "Cannot report public/protected coverage while records are unclassified" if unclassified.any?

public_records.group_by(&:first).each do |visibility, records|
  covered = records.count { |record| record[5].positive? }
  percentage = (100.0 * covered / records.length).round(4)
  puts "SUMMARY\t#{visibility}\tcovered=#{covered}\ttotal=#{records.length}\tpercent=#{percentage}"
end

covered = public_records.count { |record| record[5].positive? }
percentage = (100.0 * covered / public_records.length).round(4)
puts "SUMMARY\tpublic_protected_total\tcovered=#{covered}\ttotal=#{public_records.length}\tpercent=#{percentage}"
puts "SUMMARY\tprivate_excluded\ttotal=#{private_records.length}"
puts "SUMMARY\ttest_only_excluded\ttotal=#{test_only_records.length}"
puts "SUMMARY\tunclassified\ttotal=#{unclassified.length}"

public_records.select { |record| record[5].zero? }.each do |record|
  puts ["UNCOVERED", *record].join("\t")
end
