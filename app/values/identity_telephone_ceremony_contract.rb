# typed: false
# frozen_string_literal: true

module IdentityTelephoneCeremonyContract
  SURFACES = %w(app org).freeze
  OPERATIONS = %w(registration replacement).freeze

  module_function

  def validate_surface!(surface)
    return if SURFACES.include?(surface.to_s)

    raise IdentityTelephoneCeremony::Error, "surface is invalid"
  end
end
