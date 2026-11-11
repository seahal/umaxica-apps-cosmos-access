# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  class PublicEntrypointInventoryTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    APP_CONTROLLER_PREFIXES = %w(auth visa).freeze

    APPLICATION_CLASS_PREFIXES = %w(Auth:: Visa::).freeze

    PUBLIC_MODES = %i(bare open guest).freeze
    PRIVATE_MODES = %i(private deny_all).freeze

    DOCUMENT_PATH = Rails.root.join("docs/security/public-entrypoints.md")
    DOCUMENTED_CATEGORY_IDS = %w(
      PUBLIC_LOCAL_AUTH_ADMISSION
      PUBLIC_HEALTH
      PUBLIC_REVISION
      PUBLIC_CSP_REPORTS
      PUBLIC_WELL_KNOWN
      PUBLIC_ROBOTS_SITEMAPS
      PUBLIC_PREFERENCE
      PUBLIC_WEB_EDGE
      PUBLIC_OAUTH_OIDC_SSO
      PUBLIC_SIGN_IN_UP
      PUBLIC_AUTH_STEP_UP
      PUBLIC_SOCIAL
      PUBLIC_APPLE_NOTIFICATIONS
    ).freeze

    RouteEntry = Struct.new(:verb, :path, :controller_path, :action, :controller_class, :mode, keyword_init: true)

    test "public entrypoint documentation names every enforced category" do
      content = File.read(DOCUMENT_PATH)

      DOCUMENTED_CATEGORY_IDS.each do |category_id|
        assert_includes content, "`#{category_id}`"
      end
    end

    test "application routes resolve to locally declared authentication modes" do
      missing =
        application_route_entries.filter_map do |entry|
          next if local_authentication_declaration?(entry.controller_class)

          "#{entry.verb} #{entry.path} => #{entry.controller_path}##{entry.action}"
        end

      assert_empty missing, "Application routes must declare authentication mode locally:\n#{missing.join("\n")}"
    end

    test "public application routes are covered by the documented public categories" do
      undocumented =
        application_route_entries.filter_map do |entry|
          next unless PUBLIC_MODES.include?(entry.mode)
          next if documented_public_category(entry)

          "#{entry.mode} #{entry.verb} #{entry.path} => #{entry.controller_path}##{entry.action}"
        end

      assert_empty undocumented, "Public routes need a documented category:\n#{undocumented.join("\n")}"
    end

    test "private and deny-all routes are not public entrypoints" do
      wrongly_public =
        application_route_entries.filter_map do |entry|
          next unless PRIVATE_MODES.include?(entry.mode)
          next unless documented_public_category(entry)

          "#{entry.mode} #{entry.verb} #{entry.path} => #{entry.controller_path}##{entry.action}"
        end

      assert_empty wrongly_public, "Private routes must not match public categories:\n#{wrongly_public.join("\n")}"
    end

    test "Auth admission attachment is GET-only on the account surfaces" do
      entries =
        application_route_entries.select do |entry|
          entry.controller_path.match?(%r{\Aauth/(app|org)/ceremony_bindings\z})
        end

      assert_equal 2, entries.size
      assert_equal ["GET"], entries.map(&:verb).uniq
      assert_equal ["show"], entries.map(&:action).uniq
      assert_equal ["/ceremony_bindings"], entries.map(&:path).uniq
    end

    private

    def application_route_entries
      Rails.application.routes.routes.filter_map do |route|
        controller_path = route.defaults[:controller].to_s
        action = route.defaults[:action].to_s
        next if controller_path.blank? || action.blank?
        next unless application_controller_path?(controller_path)

        controller_class = "#{controller_path.camelize}Controller".safe_constantize
        mode = authentication_mode(controller_class, action)

        RouteEntry.new(
          verb: route.verb.presence || "ANY",
          path: route.path.spec.to_s.sub(/\(\.:format\)\z/, ""),
          controller_path: controller_path,
          action: action,
          controller_class: controller_class,
          mode: mode,
        )
      end
    end

    def application_controller_path?(controller_path)
      APP_CONTROLLER_PREFIXES.any? { |prefix| controller_path.start_with?("#{prefix}/") }
    end

    def authentication_mode(controller_class, action)
      flunk("Missing controller class for application route") if controller_class.blank?
      flunk("Unexpected controller class #{controller_class.name}") unless
        application_controller_class?(controller_class)

      if controller_class.respond_to?(:authentication_mode_for)
        controller_class.authentication_mode_for(action)
      elsif controller_class.const_defined?(:AUTHENTICATION_MODE, false)
        controller_class.const_get(:AUTHENTICATION_MODE, false)
      else
        flunk("#{controller_class.name} does not expose authentication mode metadata")
      end
    end

    def application_controller_class?(controller_class)
      controller_class.name.start_with?(*APPLICATION_CLASS_PREFIXES)
    end

    def local_authentication_declaration?(controller_class)
      controller_class.const_defined?(:AUTHENTICATION_MODE, false) ||
        (controller_class.respond_to?(:local_authentication_mode_rules) &&
          controller_class.local_authentication_mode_rules.present?)
    end

    def documented_public_category(entry)
      return false unless PUBLIC_MODES.include?(entry.mode)

      documented_public_content?(entry) || documented_public_auth?(entry) || documented_public_api?(entry)
    end

    def documented_public_content?(entry)
        public_local_auth_admission?(entry) ||
        public_health?(entry) ||
        public_revision?(entry) ||
        public_csp_report?(entry) ||
        public_well_known?(entry) ||
        public_robots_or_sitemap?(entry) ||
        public_preference?(entry) ||
        public_web_or_edge?(entry)
    end

    def documented_public_auth?(entry)
      public_oauth_oidc_or_sso?(entry) ||
        public_sign_in_or_up?(entry) ||
        public_auth_step_up?(entry) ||
        public_sign_out?(entry) ||
        public_social?(entry)
    end

    def documented_public_api?(entry)
      public_apple_notification?(entry)
    end

    def public_local_auth_admission?(entry)
      case entry.controller_path
      when %r{\Aauth/(app|org)/ceremony_bindings\z}
        get?(entry) && entry.path == "/ceremony_bindings" && entry.action == "show"
      when %r{\Avisa/(app|org)/ceremony_binding_confirmations\z}
        get?(entry) && entry.path == "/ceremony_bindings/:binding_ref/confirmation" && entry.action == "show"
      else
        false
      end
    end

    def public_health?(entry)
      get?(entry) && (entry.path.start_with?("/health") || entry.path == "/api/v0/health.json")
    end

    def public_revision?(entry)
      get?(entry) && ["/revision", "/api/v0/revision.json"].include?(entry.path)
    end

    def public_csp_report?(entry) = post?(entry) && entry.path == "/csp-violation-report"

    def public_well_known?(entry) = get?(entry) && entry.path.start_with?("/.well-known/")

    def public_robots_or_sitemap?(entry) = get?(entry) && ["/robots.txt", "/sitemap.xml"].include?(entry.path)

    def public_preference?(entry)
      entry.path.start_with?("/preference") || entry.path.start_with?("/api/v0/preferences")
    end

    def public_web_or_edge?(entry) = entry.path.start_with?("/web/v0/", "/edge/v0/")

    def public_oauth_oidc_or_sso?(entry)
      entry.path.start_with?("/oauth", "/oidc", "/sso", "/auth/", "/sign/oidc/handoff")
    end

    def public_sign_in_or_up?(entry)
      if %w(/sign/cancellation /sign/switch).include?(entry.path)
        return entry.verb == "POST" && entry.action == "create" &&
            entry.controller_path.match?(%r{\Aauth/(app|org)/sign/(cancellations|switches)\z})
      end

      entry.path == "/sign" || entry.path == "/oidc/callback" ||
        entry.path.start_with?("/sign/in", "/sign/up", "/web/v0/in/")
    end

    def public_sign_out?(entry)
      entry.path.start_with?("/sign/out") || entry.controller_path.end_with?("/sign_outs", "/sign/outs")
    end

    def public_auth_step_up?(entry)
      public_auth_verification?(entry) ||
        public_auth_settings_totp?(entry) ||
        public_visa_sensitive_admission?(entry)
    end

    def public_auth_verification?(entry)
      path_pattern, actions =
        case entry.controller_path
        when %r{\Aauth/(app|org)/verifications\z}
          [%r{\A/verification\z}, { "show" => %w(GET), "create" => %w(POST) }]
        when %r{\Aauth/(app|org)/verification/setups\z}
          [%r{\A/verification/setup(?:/new)?\z}, { "new" => %w(GET), "create" => %w(POST) }]
        when %r{\Aauth/(app|org)/verification/handoffs\z}
          [%r{\A/verification/handoff\z}, { "show" => %w(GET), "create" => %w(POST) }]
        when %r{\Aauth/(app|org)/verification/cancellations\z}
          [%r{\A/verification/cancellation\z}, { "create" => %w(POST) }]
        when %r{\Aauth/(app|org)/verification/passkeys\z}
          [%r{\A/verification/passkey(?:/(?:new|options))?\z},
           { "new" => %w(GET), "options" => %w(POST), "create" => %w(POST) },]
        when %r{\Aauth/(app|org)/verification/registration/passkeys\z}
          [%r{\A/verification/registration/passkey(?:/(?:new|options))?\z},
           { "new" => %w(GET), "options" => %w(POST), "create" => %w(POST) },]
        when %r{\Aauth/(app|org)/verification/registration/handoffs\z}
          [%r{\A/verification/registration/handoff\z}, { "show" => %w(GET), "create" => %w(POST) }]
        when "auth/app/verification/totps"
          [%r{\A/verification/totp(?:/new)?\z}, { "new" => %w(GET), "create" => %w(POST) }]
        when %r{\Aauth/(app|org)/verification/emails\z}
          [%r{\A/verification/emails(?:/new|/:id(?:/edit)?)?\z},
           { "new" => %w(GET), "edit" => %w(GET), "create" => %w(POST), "update" => %w(PATCH PUT) },]
        when %r{\Aauth/(app|org)/verification/redeliveries\z}
          [%r{\A/verification/emails/:email_id/redelivery\z}, { "create" => %w(POST) }]
        else
          return false
        end
      route_matches?(entry, path_pattern, actions)
    end

    def public_auth_settings_totp?(entry)
      path_pattern, actions =
        case entry.controller_path
        when "auth/app/settings/totps"
          [%r{\A/settings/totps(?:/new)?\z}, { "new" => %w(GET), "create" => %w(POST) }]
        when "auth/app/settings/totps/enrollments"
          [%r{\A/settings/totps/enrollment\z}, { "create" => %w(POST), "destroy" => %w(DELETE) }]
        when "auth/app/settings/totps/handoffs"
          [%r{\A/settings/totps/handoff\z}, { "show" => %w(GET), "create" => %w(POST) }]
        else
          return false
        end

      route_matches?(entry, path_pattern, actions)
    end

    def public_visa_sensitive_admission?(entry)
      path_pattern, actions =
        case entry.controller_path
        when %r{\Avisa/(app|org)/api/v0/sensitive_admissions\z}
          [%r{\A/api/v0/sensitive_admissions\z}, { "create" => %w(POST) }]
        when %r{\Avisa/(app|org)/api/v0/sensitive_admission_sessions\z}
          [%r{\A/api/v0/sensitive_admission_(?:session|confirmation)\z},
           { "create" => %w(POST), "update" => %w(PATCH PUT) },]
        else
          return false
        end

      route_matches?(entry, path_pattern, actions)
    end

    def route_matches?(entry, path_pattern, actions)
      entry.path.match?(path_pattern) && actions.fetch(entry.action, []).include?(entry.verb)
    end

    def public_social?(entry)
      entry.path.start_with?("/social/") &&
        entry.controller_path.match?(%r{\Aauth/(app|org)/(?:social|omniauth)/})
    end

    def public_apple_notification?(entry) = post?(entry) && entry.path == "/apple/notifications"

    def get?(entry) = route_allows?(entry, "GET")

    def post?(entry) = route_allows?(entry, "POST")

    def route_allows?(entry, verb)
      entry.verb.split("|").include?(verb)
    end
  end
end
