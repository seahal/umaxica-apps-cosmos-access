# typed: false
# frozen_string_literal: true

# Visa owns the OpenID Provider and browser-bound authority flows. Each realm
# is constrained to its own Visa host.
scope(module: :visa, as: :visa) do
  {
    app: :service,
    org: :staff,
  }.each do |surface_namespace, realm|
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    origin = hosts.public_send("visa_#{realm}")
    public_env = "PUBLIC_VISA_#{realm.to_s.upcase}_URL"
    local_host = "visa.#{surface_namespace}.localhost"

    constraints(host: [origin&.host, ENV[public_env], local_host].compact) do
      scope(module: surface_namespace, as: surface_namespace) do
        resource(
          :ceremony_binding_confirmation,
          only: :show,
          path: "ceremony_bindings/:binding_ref/confirmation",
          controller: "/visa/#{surface_namespace}/unavailable_ceremonies",
        )

        namespace(:well_known, path: ".well-known") do
          resource(
            :openid_configuration,
            only: :show, path: "openid-configuration", controller: :discoveries,
            format: false,
          )
          resource(:jwks, only: :show, path: "jwks.json", format: false)
        end

        resource(:health, only: :show, format: false)
        namespace(:health) do
          resource(:liveness, only: :show, format: false)
          resource(:readiness, only: :show, format: false)
          resource(:startup, only: :show, format: false)
        end
        namespace(:api) do
          namespace(:v0) do
            resources(:revocation_commands, only: :create)
            resource(:health, only: :show, path: "health.json", format: false)
            resource(:revision, only: :show, path: "revision.json", format: false)
            resources(:sensitive_admissions, only: :create)
            resource(:sensitive_admission_session, only: :update)
            resource(
              :sensitive_admission_confirmation, only: :create,
                                                 controller: :sensitive_admission_sessions,
            )
          end
        end
        resource(:revision, only: :show, format: false)
        resources(:robots, only: :index, path: "robots.txt")
        resource(:csp_violation_report, only: :create, path: "csp-violation-report")

        namespace(:oauth) do
          resource(
            :authorization, only: %i(show create), path: "authorize",
                            controller: "/visa/#{surface_namespace}/oauth/authorizations",
          )
          resource(:token, only: :create, controller: :tokens)
          resource(:userinfo, only: %i(show create), controller: :userinfos)
          resource(:revocation, only: :create, path: "revoke", controller: :revocations)
        end

        namespace(:oidc) do
          resource(:logout, only: %i(show create), controller: :logouts)
          scope(module: :logouts, path: :logout, as: :logout) do
            resource :confirmation, only: :create
            resource :completion, only: :show
          end
          resource(:result, only: :show, controller: "/visa/#{surface_namespace}/unavailable_ceremonies")
          resource(:cancellation, only: :show, controller: "/visa/#{surface_namespace}/unavailable_ceremonies")
          if surface_namespace != :org
            resource(:switch, only: :show, controller: "/visa/#{surface_namespace}/unavailable_ceremonies")
          end
        end

        namespace :sign do
          namespace :in do
            resource :limitation, only: %i(show update destroy),
                                  controller: "/visa/#{surface_namespace}/unavailable_ceremonies"
            post "limitation", to: "/visa/#{surface_namespace}/unavailable_ceremonies#update",
                               as: :limitation_continue
          end
        end

        namespace :edge do
          namespace :v0 do
            namespace :token do
              resource :status, only: :show, path: "check", controller: :checks, as: :check
              resource :dbsc, only: :create
              resource :refresh, only: :create
            end
          end
        end
      end
    end
  end
end
