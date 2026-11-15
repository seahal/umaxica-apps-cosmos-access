# typed: false
# frozen_string_literal: true

module OauthAuthorizeRateLimit
  extend ActiveSupport::Concern

  private

  def enforce_oauth_authorize_rate_limits!
    profile_set = RateLimitProfiles.oauth_authorize

    return unless oauth_authorize_rate_limit_request!(
      bucket: "ip_surface", profile: profile_set.ip_surface, key: oauth_authorize_rate_limit_ip_surface_key,
    )
    return unless oauth_authorize_rate_limit_request!(
      bucket: "browser_client", profile: profile_set.browser_client,
      key: oauth_authorize_rate_limit_browser_client_key,
    )

    oauth_authorize_rate_limit_request!(
      bucket: "client_redirect_host", profile: profile_set.client_redirect_host,
      key: oauth_authorize_rate_limit_client_redirect_host_key,
    )
  end

  def oauth_authorize_rate_limit_request!(bucket:, profile:, key:)
    count = Rails.configuration.x.rate_limit.fetch(:store).increment(key, 1, expires_in: profile.within)
    unless count.is_a?(Integer) && count.positive?
      reason = count.nil? ? "missing_counter_result" : "invalid_counter_result"
      oauth_authorize_rate_limit_backend_failure!(bucket:, reason:)
      return false
    end

    return true if count <= profile.to

    oauth_authorize_rate_limit_exceeded!(bucket:, profile:, count:)
    false
  rescue Umaxica::Valkey::Unavailable => e
    oauth_authorize_rate_limit_backend_failure!(bucket:, reason: "backend_unavailable", error_class: e.class.name)
    false
  rescue Umaxica::Valkey::OperationError => e
    oauth_authorize_rate_limit_backend_failure!(bucket:, reason: "backend_operation_error", error_class: e.class.name)
    false
  end

  def oauth_authorize_rate_limit_backend_failure!(bucket:, reason:, error_class: nil)
    Rails.logger.error(
      JitLogEvent.format(
        "oidc.authorize.rate_limit.backend_failure",
        mode: "request_window", bucket:, surface: authorization_surface, reason:, error_class:,
        request_id: request.request_id,
      ),
    )

    payload = { error: "temporarily_unavailable", error_description: I18n.t("errors.rate_limit.backend_unavailable") }
    respond_to do |format|
      format.json { render json: payload, status: :service_unavailable }
      format.html do
        render plain: payload.fetch(:error_description), content_type: "text/plain", status: :service_unavailable
      end
    end
  end

  def oauth_authorize_rate_limit_exceeded!(bucket:, profile:, count:)
    log_oauth_authorize_rate_limit_event!(
      event: "oidc.authorize.rate_limited", bucket:, profile:, count:,
    )
    render_oauth_authorize_rate_limited(bucket:, profile:)
  end

  def oauth_authorize_rate_limit_near_limit!(bucket:, profile:, count:)
    Rails.logger.info(
      JitLogEvent.format(
        "oidc.authorize.rate_limit.near_limit",
        mode: "request_window",
        bucket: bucket,
        surface: authorization_surface,
        limit: profile.to,
        period_seconds: profile.within.to_i,
        count: count,
        retry_after_seconds: profile.retry_after,
        request_id: request.request_id,
      ),
    )
  end

  def log_oauth_authorize_rate_limit_event!(event:, bucket:, profile:, count:)
    near_limit = (profile.to * 0.8).ceil
    oauth_authorize_rate_limit_near_limit!(bucket:, profile:, count:) if count == near_limit

    Rails.logger.info(
      JitLogEvent.format(
        event,
        mode: "request_window",
        bucket: bucket,
        surface: authorization_surface,
        limit: profile.to,
        period_seconds: profile.within.to_i,
        count: count,
        retry_after_seconds: profile.retry_after,
        request_id: request.request_id,
      ),
    )
  end

  def render_oauth_authorize_rate_limited(bucket:, profile:)
    response.headers["X-RateLimit-Layer"] = "rails"
    response.headers["X-RateLimit-Rule"] = "oauth_authorize_#{bucket}"
    response.headers["Retry-After"] = profile.retry_after.to_i.to_s

    payload = {
      error: "rate_limited",
      rule: "oauth_authorize_#{bucket}",
      message: I18n.t("errors.rate_limit.exceeded"),
      retry_after: profile.retry_after.to_i,
    }
    respond_to do |format|
      format.json { render json: payload, status: :too_many_requests }
      format.html do
        render plain: payload.fetch(:message), content_type: "text/plain", status: :too_many_requests
      end
    end
  end

  def oauth_authorize_rate_limit_client_id
    params[:client_id].presence
  end

  def oauth_authorize_rate_limit_ip_surface_key
    ["rate-limit", "oauth_authorize", "ip_surface", authorization_surface, request.remote_ip].join(":")
  end

  def oauth_authorize_rate_limit_browser_client_key
    [
      "rate-limit", "oauth_authorize", "browser_client", authorization_surface,
      oauth_authorize_rate_limit_browser_key, oauth_authorize_rate_limit_client_id || "unknown",
    ].join(":")
  end

  def oauth_authorize_rate_limit_browser_key
    current_session_public_id.presence || session.id.to_s.presence || "anonymous"
  end

  def oauth_authorize_rate_limit_client_redirect_host_key
    [
      "rate-limit", "oauth_authorize", "client_redirect_host", authorization_surface,
      oauth_authorize_rate_limit_client_id || "unknown", oauth_authorize_rate_limit_redirect_uri_host || "unknown",
    ].join(":")
  end

  def oauth_authorize_rate_limit_redirect_uri_host
    return if params[:redirect_uri].blank?

    URI.parse(params[:redirect_uri].to_s).host
  rescue URI::InvalidURIError
    nil
  end
end
