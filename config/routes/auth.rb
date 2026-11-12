# typed: false
# frozen_string_literal: true

# Auth owns app and org credential gateway surfaces. Visa owns the OpenID
# Provider and Authorization Server endpoints.
scope(module: :auth, as: :auth) do
  # User credential gateway host. Hosts listed declaratively (DRY intentionally broken).
  constraints(
    host: [Rails.configuration.x.boot_config.fetch(:hosts).auth_service.host, ENV["PUBLIC_AUTH_SERVICE_URL"],
           "auth.app.localhost",].compact,
  ) do
    scope(module: :app, as: :app) do
      namespace(:well_known, path: ".well-known") do
        resource(:jwks, only: :show, path: "jwks.json", format: false)
      end

      # Deployment identifier endpoint.
      resource(:revision, only: :show, format: false)

      resource(:health, only: :show, format: false)
      namespace(:health) do
        resource(:liveness, only: :show, format: false)
        resource(:readiness, only: :show, format: false)
        resource(:startup, only: :show, format: false)
      end

      # Machine-readable health and revision. The literal ".json" is part of the path, not a Rails
      # format token (`format: false`), mirroring the `.well-known/jwks.json` precedent above.
      # These are JSON-only; the controllers answer 406 to any other `Accept`.
      namespace(:api) do
        namespace(:v0) do
          resource(:health, only: :show, path: "health.json", format: false)
          resource(:revision, only: :show, path: "revision.json", format: false)
        end
      end

      resources(:robots, only: :index, path: "robots.txt")
      resource(:sitemap, only: :show, path: "sitemap.xml")
      resource(:csp_violation_report, only: :create, path: "csp-violation-report")
      resource(
        :ceremony_binding,
        only: :show, path: "ceremony_bindings",
        controller: "/auth/app/unavailable_ceremonies", as: :ceremony_bindings,
      )

      namespace :apple do
        resources :notifications, only: :create
      end

      # Canonical ceremony entrypoints and authed-out confirmation/cleanup.
      namespace :sign do
        resource :registration, only: :show, path: "up", controller: "/auth/app/unavailable_ceremonies", as: :up
        resource :session, only: :show, path: "in", controller: "/auth/app/unavailable_ceremonies", as: :in
        resource :oidc_handoff, only: :show, path: "oidc/handoff", controller: "/auth/app/unavailable_ceremonies"
        # First-page cancellation and sign-in/sign-up switching.
        resource :cancellation, only: :create, controller: "/auth/app/unavailable_ceremonies"
        resource :switch, only: :create, controller: "/auth/app/unavailable_ceremonies"
        namespace :in do
          resource :sentry, only: :show, controller: "/auth/app/unavailable_ceremonies"
        end
        namespace :up do
          resource :sentry, only: :show, controller: "/auth/app/unavailable_ceremonies"
        end
      end

      # Public web API: OTP delivery (a ceremony endpoint, not migrated).
      namespace :web do
        namespace :v0 do
          namespace :in do
            namespace :email do
              resource :otp, only: :create, controller: "/auth/app/unavailable_ceremonies"
            end
          end
        end
      end

      # Sign-up and sign-in ceremonies.
      namespace :sign do
        # Auth-up ceremony.
        namespace(:up) do
          resource(:email, only: %i(new create), controller: "/auth/app/unavailable_ceremonies")
          resource(:telephone, only: %i(new create), controller: "/auth/app/unavailable_ceremonies")

          namespace(:guard) do
            resource(:apple, only: :show, controller: "/auth/app/unavailable_ceremonies")
            resource(:google, only: :show, controller: "/auth/app/unavailable_ceremonies")
            resource(:email, only: :show, controller: "/auth/app/unavailable_ceremonies")
            resource(:telephone, only: :show, controller: "/auth/app/unavailable_ceremonies")
          end

          namespace(:check) do
            namespace(:apple) do
              resource(:confirmation, only: %i(show update destroy), controller: "/auth/app/unavailable_ceremonies")
              resource(:birthdate, only: %i(show update destroy), controller: "/auth/app/unavailable_ceremonies")
            end

            namespace(:google) do
              resource(:confirmation, only: %i(show update destroy), controller: "/auth/app/unavailable_ceremonies")
              resource(:birthdate, only: %i(show update destroy), controller: "/auth/app/unavailable_ceremonies")
            end

            namespace(:email) do
              resource(:otp, only: %i(show create update destroy), controller: "/auth/app/unavailable_ceremonies")
              resource(:birthdate, only: %i(show update destroy), controller: "/auth/app/unavailable_ceremonies")
            end

            namespace(:telephone) do
              resource(:otp, only: %i(show create update destroy), controller: "/auth/app/unavailable_ceremonies")
              resource(:passkey, only: %i(show create update destroy), controller: "/auth/app/unavailable_ceremonies")
              resource(:secret, only: %i(show create update destroy), controller: "/auth/app/unavailable_ceremonies") do
                post :reattempt
              end
              resource(:birthdate, only: %i(show update destroy), controller: "/auth/app/unavailable_ceremonies")
            end
          end
        end

        # Sign-in ceremony.
        namespace :in do
          resource :email, only: %i(new create edit update destroy), controller: "/auth/app/unavailable_ceremonies"

          resource :passkey, only: :new, controller: "/auth/app/unavailable_ceremonies"
          resource :secret, only: %i(new create), controller: "/auth/app/unavailable_ceremonies"
          namespace :passkey do
            resource :options, only: :create, controller: "/auth/app/unavailable_ceremonies"
            resource :verification, only: :create, controller: "/auth/app/unavailable_ceremonies"
          end

          resource :check, only: :show, controller: "/auth/app/unavailable_ceremonies"

          # `destroy` cancels the pending second-factor ceremony.
          resource :challenge, only: %i(show destroy), controller: "/auth/app/unavailable_ceremonies"
          namespace :challenge do
            resource :passkey, only: %i(new create), controller: "/auth/app/unavailable_ceremonies"
          end
        end
      end

      namespace(:social) do
        resource :google, only: :create, controller: "/auth/app/unavailable_ceremonies"
        resource :apple, only: :create, controller: "/auth/app/unavailable_ceremonies"
        resource :link_completion, only: :create, controller: "/auth/app/unavailable_ceremonies"
        # Existing provider callback paths refuse ceremonies without Governance.
        get(
          "google/callback",
          to: "/auth/app/unavailable_ceremonies#show",
          as: :google_callback,
          defaults: { provider: "google" },
        )

        get(
          "apple/callback",
          to: "/auth/app/unavailable_ceremonies#show",
          as: :apple_callback,
          defaults: { provider: "apple" },
        )

        get(
          "failure",
          to: "/auth/app/unavailable_ceremonies#show",
          as: :failure,
        )

        # Existing provider entry paths refuse ceremonies without Governance.
        scope :google, as: :google, defaults: { provider: "google", intent: "login" } do
          resource :session, only: :create, controller: "/auth/app/unavailable_ceremonies"
          resource :registration, only: :create, controller: "/auth/app/unavailable_ceremonies",
                                  defaults: { entry: "auth_up" }
        end

        scope :apple, as: :apple, defaults: { provider: "apple", intent: "login" } do
          resource :session, only: :create, controller: "/auth/app/unavailable_ceremonies"
          resource :registration, only: :create, controller: "/auth/app/unavailable_ceremonies",
                                  defaults: { entry: "auth_up" }
        end
      end

      # Step-up verification.
      resource :verification, only: :show, controller: "/auth/app/unavailable_ceremonies"
      namespace :verification do
        resource :cancellation, only: :create, controller: "/auth/app/unavailable_ceremonies"
      end
      namespace :verification do
        resource :setup, only: :new, controller: "/auth/app/unavailable_ceremonies"
        resource :handoff, only: %i(show create), controller: "/auth/app/unavailable_ceremonies"
        post "passkey/options", to: "/auth/app/unavailable_ceremonies#create", as: :passkey_options
        resource :passkey, only: %i(new create), controller: "/auth/app/unavailable_ceremonies"
        resource :totp, only: %i(new create), controller: "/auth/app/unavailable_ceremonies"

        namespace :registration do
          post "passkey/options", to: "/auth/app/unavailable_ceremonies#create", as: :passkey_options
          resource :passkey, only: %i(new create), controller: "/auth/app/unavailable_ceremonies"
          resource :handoff, only: %i(show create), controller: "/auth/app/unavailable_ceremonies"
        end

        resources :emails, only: %i(new create edit update), controller: "/auth/app/unavailable_ceremonies" do
          resource :redelivery, only: :create, controller: "/auth/app/unavailable_ceremonies"
        end
      end

      # Credential setup is unavailable until the Governance credential API is implemented.
      namespace :settings do
        namespace :totps do
          resource :enrollment, only: %i(create destroy), controller: "/auth/app/unavailable_ceremonies"
          resource :handoff, only: %i(show create), controller: "/auth/app/unavailable_ceremonies"
        end
        resources :totps, only: %i(new create), controller: "/auth/app/unavailable_ceremonies"
        resource :apple, only: %i(show edit create destroy), controller: "/auth/app/unavailable_ceremonies"
        resource :google, only: %i(show edit create destroy), controller: "/auth/app/unavailable_ceremonies"
      end
    end
  end

  # Staff credential gateway host.
  constraints(
    host: [Rails.configuration.x.boot_config.fetch(:hosts).auth_staff.host, ENV["PUBLIC_AUTH_STAFF_URL"],
           "auth.org.localhost",].compact,
  ) do
    scope(module: :org, as: :org) do
      namespace(:well_known, path: ".well-known") do
        resource(:jwks, only: :show, path: "jwks.json", format: false)
      end

      # Deployment identifier endpoint.
      resource(:revision, only: :show, format: false)

      resource(:health, only: :show, format: false)
      namespace(:health) do
        resource(:liveness, only: :show, format: false)
        resource(:readiness, only: :show, format: false)
        resource(:startup, only: :show, format: false)
      end

      # Machine-readable health and revision. The literal ".json" is part of the path, not a Rails
      # format token (`format: false`), mirroring the `.well-known/jwks.json` precedent above.
      # These are JSON-only; the controllers answer 406 to any other `Accept`.
      namespace(:api) do
        namespace(:v0) do
          resource(:health, only: :show, path: "health.json", format: false)
          resource(:revision, only: :show, path: "revision.json", format: false)
        end
      end

      resources(:robots, only: :index, path: "robots.txt")
      resource(:sitemap, only: :show, path: "sitemap.xml")
      resource(:csp_violation_report, only: :create, path: "csp-violation-report")
      resource(
        :ceremony_binding,
        only: :show, path: "ceremony_bindings",
        controller: "/auth/org/unavailable_ceremonies", as: :ceremony_bindings,
      )

      # Staff management areas.

      # Canonical ceremony entrypoints and authed-out confirmation.
      namespace :sign do
        resource :registration, only: :show, path: "up", controller: "/auth/org/unavailable_ceremonies", as: :up
        resource :session, only: :show, path: "in", controller: "/auth/org/unavailable_ceremonies", as: :in
        resource :oidc_handoff, only: :show, path: "oidc/handoff", controller: "/auth/org/unavailable_ceremonies"
        # First-page cancellation. Org has no public sign-up, so it has no switch action.
        resource :cancellation, only: :create, controller: "/auth/org/unavailable_ceremonies"
        namespace :in do
          resource :sentry, only: :show, controller: "/auth/org/unavailable_ceremonies"
        end
        namespace :up do
          resource :sentry, only: :show, controller: "/auth/org/unavailable_ceremonies"
        end
      end

      # Sign-up and sign-in ceremonies.
      namespace :sign do
        # Sign-in ceremony.
        namespace :in do
          resource :passkey, only: :new, controller: "/auth/org/unavailable_ceremonies"

          namespace :passkey do
            resource :options, only: :create, controller: "/auth/org/unavailable_ceremonies"
            resource :verification, only: :create, controller: "/auth/org/unavailable_ceremonies"
          end

          # Emergency Access (Restricted Mode). Org only, Passkey only, and no
          # Entra stage: it is the way in when the Entra path is unavailable.
          # The ceremony is the same shape as the normal passkey ceremony above
          # because it is the same implementation with a different ceremony
          # purpose and post-verification context; only the entry differs.
          # There is deliberately no emergency sign-up and no emergency
          # sign-out -- both modes terminate through Visa's OIDC logout surface.
          # See docs/security/org-emergency-access.md.
          namespace :emergency do
            resource :passkey, only: :new, controller: "/auth/org/unavailable_ceremonies"

            namespace :passkey do
              resource :options, only: :create, controller: "/auth/org/unavailable_ceremonies"
              resource :verification, only: :create, controller: "/auth/org/unavailable_ceremonies"
            end
          end

          resource :check, only: :show, controller: "/auth/org/unavailable_ceremonies"
          # No second-factor challenge: every org sign-in completes as a passkey sign-in, which
          # bypasses MFA, so no org state reaches MFA_PENDING.
        end
      end

      # OmniAuth-based Entra ID (Microsoft) sign-in.
      # See adr/org-entra-omniauth-strategy-migration.md.
      namespace(:social) do
        resource :entra, only: :create, controller: "/auth/org/unavailable_ceremonies"
        scope :entra, as: :entra, defaults: { provider: "entra" } do
          resource :session, only: %i(new create), controller: "/auth/org/unavailable_ceremonies"
        end

        # Existing Entra callback paths refuse ceremonies without Governance.
        get(
          "entra/callback",
          to: "/auth/org/unavailable_ceremonies#show",
          as: :entra_callback,
          defaults: { provider: "entra" },
        )

        get(
          "entra/failure",
          to: "/auth/org/unavailable_ceremonies#show",
          as: :entra_failure,
        )
      end

      # Step-up verification.
      resource :verification, only: :show, controller: "/auth/org/unavailable_ceremonies"
      namespace :verification do
        resource :cancellation, only: :create, controller: "/auth/org/unavailable_ceremonies"
      end
      namespace :verification do
        resource :setup, only: :new, controller: "/auth/org/unavailable_ceremonies"
        resource :handoff, only: %i(show create), controller: "/auth/org/unavailable_ceremonies"
        post "passkey/options", to: "/auth/org/unavailable_ceremonies#create", as: :passkey_options
        resource :passkey, only: %i(new create), controller: "/auth/org/unavailable_ceremonies"

        namespace :registration do
          post "passkey/options", to: "/auth/org/unavailable_ceremonies#create", as: :passkey_options
          resource :passkey, only: %i(new create), controller: "/auth/org/unavailable_ceremonies"
          resource :handoff, only: %i(show create), controller: "/auth/org/unavailable_ceremonies"
        end
      end
    end
  end
end
