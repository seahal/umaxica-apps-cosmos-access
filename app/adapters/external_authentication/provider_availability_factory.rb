# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class ProviderAvailabilityFactory
    def self.current
      FlipperProviderAvailabilityAdapter.new
    end
    public_class_method :current
  end
end
