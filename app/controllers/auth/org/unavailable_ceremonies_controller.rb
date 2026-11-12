# typed: false
# frozen_string_literal: true

module Auth
  module Org
    class UnavailableCeremoniesController < BareController
      AUTHENTICATION_MODE = :bare

      sign_entry_classification! :excluded, reason: "credential ceremonies unavailable until Governance integration"

      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "auth_org_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { head :too_many_requests },
      )

      public

      def show
        render_unavailable
      end

      def new
        render_unavailable
      end

      def edit
        render_unavailable
      end

      def create
        render_unavailable
      end

      def update
        render_unavailable
      end

      def destroy
        render_unavailable
      end

      def reattempt
        render_unavailable
      end

      private

      def render_unavailable
        response.headers["Referrer-Policy"] = "no-referrer"
        render plain: "Service unavailable", status: :service_unavailable
      end
    end
  end
end
