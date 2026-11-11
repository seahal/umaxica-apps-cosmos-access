# typed: false
# frozen_string_literal: true

module IdentityTotpCeremonyContract
  Error = Class.new(StandardError)
  SURFACES = %w(app org).freeze
  OPERATIONS = %w(registration replacement).freeze
end
