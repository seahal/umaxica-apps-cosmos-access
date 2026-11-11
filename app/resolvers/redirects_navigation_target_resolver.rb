# typed: false
# frozen_string_literal: true

class RedirectsNavigationTargetResolver
  REGISTRY = {
    checkpoint: ->(routes, params) {
      routes.public_send(
        "auth_#{RedirectsNavigationTargetResolver.surface(params)}_sign_in_check_path",
        ri: params[:ri],
      )
    },
    selector: ->(routes, params) {
      routes.public_send(
        "auth_#{RedirectsNavigationTargetResolver.surface(params)}_sign_in_path",
        ri: params[:ri],
      )
    },
  }.freeze

  SCOPES = {
    authentication: %i(checkpoint selector).freeze,
  }.freeze

  def self.call(key, routes:, params: {}, scope: nil, source: :explicit_nt)
    new(key, routes: routes, params: params, scope: scope, source: source).call
  end

  def initialize(key, routes:, params:, scope:, source:)
    @key = key
    @routes = routes
    @params = params.to_h.symbolize_keys
    @scope = scope&.to_sym
    @source = source
  end

  def call
    return failure(:raw_url) if raw_url_or_path?

    registry_key = normalize_key
    return failure(:unknown_key) unless REGISTRY.key?(registry_key)
    return failure(:scope_denied) unless allowed_in_scope?(registry_key)

    result = RedirectsPathTargetResolver.call(REGISTRY.fetch(registry_key).call(routes, params), source: source)
    return RedirectsTargetResult.ok(kind: :nt, source: source, value: result.value) if result.ok?

    RedirectsTargetResult.failure(
      kind: :nt, source: source, reason: "invalid_registered_path",
      unsafe_value: result.value,
    )
  end

  def self.surface(params)
    params[:surface].presence || "app"
  end

  private

  attr_reader :key, :routes, :params, :scope, :source

  def normalize_key
    return key if key.is_a?(Symbol)

    key.to_sym if key.is_a?(String) && key.match?(/\A[a-z][a-z0-9_]*\z/)
  end

  def raw_url_or_path?
    key.is_a?(String) && (key.include?("/") || key.include?(":") || key.include?("\\"))
  end

  def allowed_in_scope?(registry_key)
    return true if scope.blank?

    SCOPES.fetch(scope, []).include?(registry_key)
  end

  def failure(reason)
    RedirectsTargetResult.failure(kind: :nt, source: source, reason: reason, unsafe_value: key)
  end
end
