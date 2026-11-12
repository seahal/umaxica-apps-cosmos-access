# typed: false
# frozen_string_literal: true

class JsonbKeysUniquenessValidator < ActiveRecord::Validations::UniquenessValidator
  def initialize(options)
    keys = options.fetch(:keys)
    unless keys.is_a?(Array) && keys.any? && keys.all? { |key| key.is_a?(String) && key.present? } && keys.uniq == keys
      raise ArgumentError, "keys must be distinct nonempty JSON object keys"
    end
    raise ArgumentError, "JSON text uniqueness is case sensitive" if options[:case_sensitive] == false

    super(options.merge(keys: keys.map { |key| key.dup.freeze }.freeze))
  end

  private

  def build_relation(klass, attribute, value)
    column = klass.arel_table[attribute]
    encoded = Arel::Nodes::InfixOperation.new("::", Arel::Nodes.build_quoted(JSON.generate(value)), Arel.sql("jsonb"))
    options.fetch(:keys).reduce(klass.all_queries_scope) do |relation, key|
      quoted_key = Arel::Nodes.build_quoted(key)
      left = Arel::Nodes::InfixOperation.new("->>", column, quoted_key)
      right = Arel::Nodes::InfixOperation.new("->>", encoded, quoted_key)
      relation.where(left.eq(right))
    end
  end
end
