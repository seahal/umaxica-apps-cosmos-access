# typed: false
# frozen_string_literal: true

module Auth
  module Org
    class PreferencesBaseController < ::Auth::Org::ApplicationController
      # D-59: the preference transport API is not a Sign Entry.
      sign_entry_classification! :excluded, reason: "preference transport API, not a sign entry"

      AUTHENTICATION_MODE = :open
      PREFERENCE_WRITE_CONTEXT = {
        surface_key: "auth/org",
        realm: "org",
        preference_model: OrgPreference,
        issuer_id: "preference_org",
      }.freeze

      layout "auth/org/application"

      ensure_fqdn_gate_first!
      # Restores the inherited default no-store ahead of the gate (DefaultNoStore).
      prepend_before_action :apply_default_no_store
      before_action :authorize_preference_write!, if: :preference_write_request?

      private

      def preference_write_context = PREFERENCE_WRITE_CONTEXT

      def set_preferences_cookie
        return if request.host.end_with?(".localhost")

        super
      end

      def preference_write_request?
        !request.get? && !request.head?
      end

      def authorize_preference_write!
        authorize!(@preferences || preference_class, to: :update?)
      end

    end
  end
end
