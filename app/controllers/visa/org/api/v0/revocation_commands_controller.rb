# frozen_string_literal: true

module Visa
  module Org
    module Api
      module V0
        # A machine-to-machine signature is the sole authority; browser credentials are unused.
        class RevocationCommandsController < ActionController::API
          include ::FqdnAvailabilityGate
          include ::RateLimit
          include ::DefaultNoStore
          include ::ProblemDetailsRendering

          AUTHENTICATION_MODE = :open
          REALM = "org"

          prepend_before_action :enforce_fqdn_availability!
          prepend_before_action :apply_default_no_store
          rate_limit(
            to: 20, within: 1.minute, by: -> { request.remote_ip },
            scope: "visa_org_governance_revocation", name: "command_ip", store: rate_limit_store,
            only: :create, with: -> { render_problem(:rate_limited) },
          )

          public

          def create
            return render_problem(:authorization_denied) if request.headers["Origin"] ||
              request.headers["Sec-Fetch-Site"]
            return render_problem(:unsupported_media_type) unless request.media_type == "application/jwt"
            return render_problem(:content_too_large) if request.content_length.to_i >
              GovernanceRevocationCommandVerifier::MAX_TOKEN_BYTES

            token = request.body.read(GovernanceRevocationCommandVerifier::MAX_TOKEN_BYTES + 1)
            return render_problem(:content_too_large) if token.bytesize >
              GovernanceRevocationCommandVerifier::MAX_TOKEN_BYTES

            acknowledgement = GovernanceRevocationCoordinator.call(token:, realm: REALM)
            render body: acknowledgement, content_type: "application/jwt", status: :ok
          rescue GovernanceRevocationCommandVerifier::Rejected
            render_problem(:authentication_required)
          rescue GovernanceRevocationCommand::Conflict
            render_problem(:bad_request)
          rescue GovernanceRevocationCommand::Forbidden
            render_problem(:authorization_denied)
          rescue GovernanceRevocationCommand::NotFound
            render_problem(:not_found)
          rescue GovernanceRevocationCommandVerifier::Unavailable,
                 GovernanceRevocationCommandVerifier::ConfigurationError,
                 GovernanceRevocationCommand::InconsistentAuthority,
                 GovernanceRevocationCoordinator::Uncommitted,
                 JitSecurityJwtRegistry::ConfigurationError,
                 ActiveRecord::ActiveRecordError, PG::Error, KeyError
            render_problem(:service_unavailable)
          end
        end
      end
    end
  end
end
