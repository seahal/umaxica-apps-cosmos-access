# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    # The no-server-call decision is about Access-to-Governance application APIs. External identity
    # provider adapters and Turnstile remain separate provider boundaries. The only handoff HTTP
    # client in this flow is the dedicated Base public-JWKS reader.
    class BaseSignInInterApplicationHttpInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      AUTH_CONTROLLER_ROOTS = %w(
        app/controllers/auth/app/sign
        app/controllers/auth/org/sign
      ).freeze
      AUTH_FLOW_FILES = %w(
        app/controllers/concerns/oidc_authorization_start.rb
        app/controllers/concerns/oidc_authorization_request_errors.rb
        app/controllers/visa/app/oauth/authorizations_controller.rb
        app/controllers/visa/org/oauth/authorizations_controller.rb
        app/services/base_auth_admission_coordinator.rb
        app/services/oidc_authorization_transaction_coordinator.rb
        app/resolvers/oidc_authorize_request_resolver.rb
        app/services/oidc_token_exchange_coordinator.rb
        app/models/client_sign_in_flow.rb
        app/models/operator_sign_in_flow.rb
        app/models/client_sign_up_flow.rb
        app/models/operator_sign_up_flow.rb
      ).freeze
      BASE_JWKS_CLIENT = "app/adapters/base_relying_party_jwks_client.rb"
      DIRECT_HTTP_CLIENT =
        /\b(?:OutboundHttp::Connection|Faraday::Connection|Faraday\.new|Net::HTTP|URI\.open|OpenURI|HTTParty|RestClient|Excon|Typhoeus|HTTPX)\b/

      test "sign-in orchestration has no direct inter-application HTTP client outside Base JWKS" do
        controller_files = AUTH_CONTROLLER_ROOTS.flat_map do |root|
          Rails.root.glob("#{root}/**/*.rb").map { |path| path.relative_path_from(Rails.root).to_s }
        end
        scanned_paths = (controller_files + AUTH_FLOW_FILES + [BASE_JWKS_CLIENT]).uniq
        missing = scanned_paths.reject { |path| Rails.root.join(path).file? }
        assert_empty missing, "Sign-in HTTP boundary source inventory is stale: #{missing.join(", ")}"

        http_call_sites = scanned_paths.filter_map do |relative_path|
          matches = Rails.root.join(relative_path).readlines.each_with_index.filter_map do |line, index|
            next if line.lstrip.start_with?("#")
            next unless line.match?(DIRECT_HTTP_CLIENT)

            "#{relative_path}:#{index + 1}"
          end
          [relative_path, matches] if matches.present?
        end

        assert_equal [BASE_JWKS_CLIENT], http_call_sites.map(&:first),
                     "Inter-application handoffs may read Base JWKS only; found #{http_call_sites.inspect}"
      end
    end
  end
end
