# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthSignCeremonyRouteContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  AUTH_APP_HOST = "auth.app.localhost"
  AUTH_ORG_HOST = "auth.org.localhost"

  def assert_recognizes(expected, options)
    route = Rails.application.routes.recognize_path(options.fetch(:path), method: options.fetch(:method))

    assert_equal expected.fetch(:controller), route.fetch(:controller)
    assert_equal expected.fetch(:action), route.fetch(:action)
  end

  # rubocop:disable Minitest/MultipleAssertions
  test "auth app route contract" do
    assert_recognizes(
      { controller: "unknown_hosts", action: "show" },
      { path: "http://#{AUTH_APP_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/well_known/jwks", action: "show" },
      { path: "http://#{AUTH_APP_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/healths", action: "show" },
      { path: "http://#{AUTH_APP_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/health/livenesses", action: "show" },
      { path: "http://#{AUTH_APP_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/health/readinesses", action: "show" },
      { path: "http://#{AUTH_APP_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/health/startups", action: "show" },
      { path: "http://#{AUTH_APP_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/robots", action: "index" },
      { path: "http://#{AUTH_APP_HOST}/robots.txt", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/sitemaps", action: "show" },
      { path: "http://#{AUTH_APP_HOST}/sitemap.xml", method: :get },
    )

    %i(get post patch put delete).each do |method|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{AUTH_APP_HOST}/sign/out", method: method)
      end
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_APP_HOST}/sign/out/complete", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_APP_HOST}/sign/out/cancellation", method: :post)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_APP_HOST}/oidc/logout", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_APP_HOST}/oidc/logout", method: :post)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_APP_HOST}/oidc/backchannel/logout", method: :post)
    end

    assert_recognizes(
      { controller: "auth/app/csp_violation_reports", action: "create" },
      { path: "http://#{AUTH_APP_HOST}/csp-violation-report", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/apple/notifications", action: "create" },
      { path: "http://#{AUTH_APP_HOST}/apple/notifications", method: :post },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_APP_HOST}/dashboard", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_APP_HOST}/billings", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_APP_HOST}/oidc/callback", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_APP_HOST}/oidc/authorization", method: :get)
    end

    assert_recognizes(
      { controller: "auth/app/sign/ups", action: "show" },
      { path: "http://#{AUTH_APP_HOST}/sign/up", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/sign/up/check/apple/confirmations", action: "destroy" },
      { path: "http://#{AUTH_APP_HOST}/sign/up/check/apple/confirmation", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/app/sign/up/check/apple/birthdates", action: "destroy" },
      { path: "http://#{AUTH_APP_HOST}/sign/up/check/apple/birthdate", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/app/sign/up/check/email/otps", action: "destroy" },
      { path: "http://#{AUTH_APP_HOST}/sign/up/check/email/otp", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/app/sign/up/check/email/birthdates", action: "destroy" },
      { path: "http://#{AUTH_APP_HOST}/sign/up/check/email/birthdate", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/app/sign/up/check/telephone/otps", action: "destroy" },
      { path: "http://#{AUTH_APP_HOST}/sign/up/check/telephone/otp", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/app/sign/up/check/telephone/passkeys", action: "destroy" },
      { path: "http://#{AUTH_APP_HOST}/sign/up/check/telephone/passkey", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/app/sign/up/check/telephone/birthdates", action: "destroy" },
      { path: "http://#{AUTH_APP_HOST}/sign/up/check/telephone/birthdate", method: :delete },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_APP_HOST}/sign/up/email", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_APP_HOST}/sign/up/check/email/cancellation", method: :post)
    end

    assert_recognizes(
      { controller: "auth/app/sign/ins", action: "show" },
      { path: "http://#{AUTH_APP_HOST}/sign/in", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/sign/in/emails", action: "new" },
      { path: "http://#{AUTH_APP_HOST}/sign/in/email/new", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/sign/in/emails", action: "create" },
      { path: "http://#{AUTH_APP_HOST}/sign/in/email", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/sign/in/emails", action: "edit" },
      { path: "http://#{AUTH_APP_HOST}/sign/in/email/edit", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/sign/in/emails", action: "update" },
      { path: "http://#{AUTH_APP_HOST}/sign/in/email", method: :patch },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_APP_HOST}/sign/in/limitation", method: :get)
    end

    ["/sign/up/entrance", "/sign/in/entrance"].each do |bad_path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{AUTH_APP_HOST}#{bad_path}", method: :get)
      end
    end

    assert_recognizes(
      { controller: "auth/app/sign/in/checks", action: "show" },
      { path: "http://#{AUTH_APP_HOST}/sign/in/check", method: :get },
    )

    %i(patch delete).each do |method|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{AUTH_APP_HOST}/sign/in/check", method: method)
      end
    end

    assert_recognizes(
      { controller: "auth/app/verification/cancellations", action: "create" },
      { path: "http://#{AUTH_APP_HOST}/verification/cancellation", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/sign/in/challenges", action: "show" },
      { path: "http://#{AUTH_APP_HOST}/sign/in/challenge", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/sign/in/passkeys", action: "new" },
      { path: "http://#{AUTH_APP_HOST}/sign/in/passkey/new", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/sign/in/passkey/options", action: "create" },
      { path: "http://#{AUTH_APP_HOST}/sign/in/passkey/options", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/sign/in/passkey/verifications", action: "create" },
      { path: "http://#{AUTH_APP_HOST}/sign/in/passkey/verification", method: :post },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_APP_HOST}/settings", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{AUTH_APP_HOST}/settings/passkeys",
        method: :get,
      )
    end
  end
  # rubocop:enable Minitest/MultipleAssertions

  test "auth app-only route contract" do
    %w(
      /social/apple/connection
      /social/apple/disconnection
      /social/google/connection
      /social/google/disconnection
    ).each do |path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{AUTH_APP_HOST}#{path}", method: :get)
      end
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{AUTH_APP_HOST}#{path}", method: :post)
      end
    end

    assert_recognizes(
      { controller: "auth/app/omniauth/omniauth_callbacks", action: "omniauth" },
      { path: "http://#{AUTH_APP_HOST}/social/google/callback", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/omniauth/omniauth_callbacks", action: "omniauth" },
      { path: "http://#{AUTH_APP_HOST}/social/apple/callback", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{AUTH_APP_HOST}/social/apple/callback",
        method: :post,
      )
    end

    assert_recognizes(
      { controller: "auth/app/omniauth/omniauth_callbacks", action: "failure" },
      { path: "http://#{AUTH_APP_HOST}/social/failure", method: :get },
    )

    %w(/auth /auth/callback /auth/logout /auth/google_app/callback /auth/apple/callback /auth/failure
       /social/auth/google_app/continue /social/auth/apple/continue).each do |path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{AUTH_APP_HOST}#{path}", method: :get)
      end
    end

    # The ceremony is POST only. A GET entry carries no CSRF token, so a link
    # could start it, which is login CSRF.
    %w(google apple).each do |_provider|
      %W(/social/\#{provider}/session /social/\#{provider}/session/new
         /social/\#{provider}/registration /social/\#{provider}/registration/new).each do |_path|
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("http://\#{AUTH_APP_HOST}\#{path}", method: :get)
        end
      end
    end

    assert_recognizes(
      { controller: "auth/app/social/sessions", action: "create", provider: "google", intent: "login" },
      { path: "http://#{AUTH_APP_HOST}/social/google/session", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/social/registrations",
        action: "create",
        provider: "google",
        intent: "login",
        entry: "auth_up", },
      { path: "http://#{AUTH_APP_HOST}/social/google/registration", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/social/sessions", action: "create", provider: "apple", intent: "login" },
      { path: "http://#{AUTH_APP_HOST}/social/apple/session", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/social/registrations",
        action: "create",
        provider: "apple",
        intent: "login",
        entry: "auth_up", },
      { path: "http://#{AUTH_APP_HOST}/social/apple/registration", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/omniauth/omniauth_callbacks", action: "omniauth" },
      { path: "http://#{AUTH_APP_HOST}/social/google/callback", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/omniauth/omniauth_callbacks", action: "omniauth" },
      { path: "http://#{AUTH_APP_HOST}/social/apple/callback", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{AUTH_APP_HOST}/social/apple/callback",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{AUTH_APP_HOST}/settings/totps",
        method: :get,
      )
    end

    assert_recognizes(
      { controller: "auth/app/settings/apples", action: "show" },
      { path: "http://#{AUTH_APP_HOST}/settings/apple", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/settings/apples", action: "edit" },
      { path: "http://#{AUTH_APP_HOST}/settings/apple/edit", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/settings/apples", action: "create" },
      { path: "http://#{AUTH_APP_HOST}/settings/apple", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/settings/apples", action: "destroy" },
      { path: "http://#{AUTH_APP_HOST}/settings/apple", method: :delete },
    )

    assert_recognizes(
      { controller: "auth/app/settings/googles", action: "show" },
      { path: "http://#{AUTH_APP_HOST}/settings/google", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/settings/googles", action: "edit" },
      { path: "http://#{AUTH_APP_HOST}/settings/google/edit", method: :get },
    )

    assert_recognizes(
      { controller: "auth/app/settings/googles", action: "create" },
      { path: "http://#{AUTH_APP_HOST}/settings/google", method: :post },
    )

    assert_recognizes(
      { controller: "auth/app/settings/googles", action: "destroy" },
      { path: "http://#{AUTH_APP_HOST}/settings/google", method: :delete },
    )

    %w(/settings/apple /settings/google).each do |path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{AUTH_APP_HOST}#{path}", method: :patch)
      end
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{AUTH_APP_HOST}/settings/secret_credentials",
        method: :get,
      )
    end
  end

  # Auth org owns the Entra credential ceremony and no app-only credentials.
  # rubocop:disable Minitest/MultipleAssertions
  test "auth org route contract" do
    assert_recognizes(
      { controller: "unknown_hosts", action: "show" },
      { path: "http://#{AUTH_ORG_HOST}/", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/well_known/jwks", action: "show" },
      { path: "http://#{AUTH_ORG_HOST}/.well-known/jwks.json", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/healths", action: "show" },
      { path: "http://#{AUTH_ORG_HOST}/health", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/health/livenesses", action: "show" },
      { path: "http://#{AUTH_ORG_HOST}/health/liveness", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/health/readinesses", action: "show" },
      { path: "http://#{AUTH_ORG_HOST}/health/readiness", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/health/startups", action: "show" },
      { path: "http://#{AUTH_ORG_HOST}/health/startup", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/robots", action: "index" },
      { path: "http://#{AUTH_ORG_HOST}/robots.txt", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/sitemaps", action: "show" },
      { path: "http://#{AUTH_ORG_HOST}/sitemap.xml", method: :get },
    )

    %i(get post patch put delete).each do |method|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{AUTH_ORG_HOST}/sign/out", method: method)
      end
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_ORG_HOST}/sign/out/complete", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_ORG_HOST}/sign/out/cancellation", method: :post)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_ORG_HOST}/oidc/logout", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_ORG_HOST}/oidc/logout", method: :post)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_ORG_HOST}/oidc/backchannel/logout", method: :post)
    end

    assert_recognizes(
      { controller: "auth/org/csp_violation_reports", action: "create" },
      { path: "http://#{AUTH_ORG_HOST}/csp-violation-report", method: :post },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_ORG_HOST}/dashboard", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_ORG_HOST}/oidc/callback", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_ORG_HOST}/oidc/authorization", method: :get)
    end

    assert_recognizes(
      { controller: "auth/org/sign/ups", action: "show" },
      { path: "http://#{AUTH_ORG_HOST}/sign/up", method: :get },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_ORG_HOST}/sign/up/email", method: :get)
    end

    assert_recognizes(
      { controller: "auth/org/sign/ins", action: "show" },
      { path: "http://#{AUTH_ORG_HOST}/sign/in", method: :get },
    )

    ["/sign/up/entrance", "/sign/in/entrance"].each do |bad_path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{AUTH_ORG_HOST}#{bad_path}", method: :get)
      end
    end

    assert_recognizes(
      { controller: "auth/org/sign/in/checks", action: "show" },
      { path: "http://#{AUTH_ORG_HOST}/sign/in/check", method: :get },
    )

    %i(patch delete).each do |method|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{AUTH_ORG_HOST}/sign/in/check", method: method)
      end
    end

    assert_recognizes(
      { controller: "auth/org/verification/cancellations", action: "create" },
      { path: "http://#{AUTH_ORG_HOST}/verification/cancellation", method: :post },
    )

    assert_recognizes(
      { controller: "auth/org/sign/in/passkeys", action: "new" },
      { path: "http://#{AUTH_ORG_HOST}/sign/in/passkey/new", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/sign/in/passkey/options", action: "create" },
      { path: "http://#{AUTH_ORG_HOST}/sign/in/passkey/options", method: :post },
    )

    assert_recognizes(
      { controller: "auth/org/sign/in/passkey/verifications", action: "create" },
      { path: "http://#{AUTH_ORG_HOST}/sign/in/passkey/verification", method: :post },
    )

    # Entra sign-in ceremony start. Sign-in only: the org surface has no social
    # registration counterpart to the app surface's social/*/registration.
    assert_recognizes(
      { controller: "auth/org/social/sessions", action: "new", provider: "entra" },
      { path: "http://#{AUTH_ORG_HOST}/social/entra/session/new", method: :get },
    )

    assert_recognizes(
      { controller: "auth/org/social/sessions", action: "create", provider: "entra" },
      { path: "http://#{AUTH_ORG_HOST}/social/entra/session", method: :post },
    )

    %w(/social/entra/registration /social/entra/registration/new).each do |path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{AUTH_ORG_HOST}#{path}", method: :get)
      end
    end
  end

  test "auth org route contract (continued)" do
    %w(/settings /settings/entra /settings/entra/edit).each do |path|
      %i(get post put patch delete).each do |method|
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("http://#{AUTH_ORG_HOST}#{path}", method: method)
        end
      end
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{AUTH_ORG_HOST}/settings/passkeys",
        method: :get,
      )
    end

    %w(/settings/sessions /settings/activities).each do |path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{AUTH_ORG_HOST}#{path}", method: :get)
      end
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_ORG_HOST}/configuration", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{AUTH_ORG_HOST}/billing", method: :get)
    end
  end

  # rubocop:enable Minitest/MultipleAssertions

  test "Auth does not expose Visa OP endpoints" do
    [AUTH_APP_HOST, AUTH_ORG_HOST].each do |host|
      %w(
        /authorize /token /userinfo /jwks /oauth/authorize /oauth/token /oauth/userinfo /oauth/jwks
        /oidc/backchannel_logout /oidc/frontchannel_logout
      ).each do |path|
        %i(get post).each do |method|
          assert_raises(ActionController::RoutingError) do
            Rails.application.routes.recognize_path("http://#{host}#{path}", method: method)
          end
        end
      end
    end
  end
end
