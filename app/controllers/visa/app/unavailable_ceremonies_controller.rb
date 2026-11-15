# typed: false
# frozen_string_literal: true

module Visa
  module App
    class UnavailableCeremoniesController < BareController
      AUTHENTICATION_MODE = :bare

      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "visa_app_authority_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { render_rate_limited(retry_after: 60) },
      )

      public

      def show
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

      private

      def render_unavailable
        response.headers["Referrer-Policy"] = "no-referrer"
        render plain: "Service unavailable", status: :service_unavailable
      end
    end
  end
end
