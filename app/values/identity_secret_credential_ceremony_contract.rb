# typed: false
# frozen_string_literal: true

module IdentitySecretCredentialCeremonyContract
  Error = Class.new(StandardError)
  SURFACES = %w(app org).freeze
  OPERATIONS = %w(enrollment replacement).freeze
end
