# frozen_string_literal: true

require "digest"
require "json"

# The signed authorization facts are retained independently of a retry's transport lifetime.
class GovernanceRevocationCommandValue
  class Invalid < StandardError; end

  MAX_LIFETIME = 60
  CLOCK_SKEW = 5
  UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/
  PRINCIPAL_PATTERN = /\A[A-Za-z0-9_-]{1,255}\z/
  ACTOR_PATTERN = /\A(?:cli|opr)_[A-Za-z0-9_-]{1,255}\z/
  SESSION_PATTERN = /\A[A-Za-z0-9_-]{21}\z/
  REASON_PATTERN = /\A[a-z][a-z0-9_.-]{0,63}\z/
  REQUIRED_KEYS = %w(iss aud iat exp jti realm sub scope actor reason).freeze
  OPTIONAL_KEYS = %w(session_public_id).freeze
  SNAPSHOT_KEYS = %w(realm sub scope actor reason session_public_id).freeze
  SUBJECT_PREFIXES = { "app" => "cli_", "org" => "opr_" }.freeze

  attr_reader :payload, :snapshot, :digest, :principal_public_id

  def initialize(payload:, realm:, issuer:, audience:, now:)
    validate_payload!(payload, realm:, issuer:, audience:, now:)
    @payload = payload.transform_values { |value| value.is_a?(String) ? value.dup.freeze : value }.freeze
    @snapshot = @payload.slice(*SNAPSHOT_KEYS).freeze
    @principal_public_id = @payload.fetch("sub").delete_prefix(SUBJECT_PREFIXES.fetch(realm)).freeze
    semantic_payload = @payload.slice("iss", "aud", "jti", *SNAPSHOT_KEYS)
    @digest = Digest::SHA256.digest(JSON.generate(semantic_payload)).freeze
    freeze
  end

  public

  def command_id = payload.fetch("jti")

  def issuer = payload.fetch("iss")

  def realm = payload.fetch("realm")

  def scope = payload.fetch("scope")

  def session_public_id = payload.fetch("session_public_id")

  private

  def validate_payload!(candidate, realm:, issuer:, audience:, now:)
    raise Invalid, "command must contain only the documented claims" unless candidate.is_a?(Hash) &&
      (REQUIRED_KEYS - candidate.keys).empty? && (candidate.keys - REQUIRED_KEYS - OPTIONAL_KEYS).empty?
    raise Invalid, "command issuer or audience does not match" unless candidate["iss"] == issuer &&
      candidate["aud"] == audience && issuer.is_a?(String) && !issuer.empty?
    raise Invalid, "command realm does not match" unless %w(app org).include?(realm) && candidate["realm"] == realm
    raise Invalid, "command identifier must be a UUID" unless candidate["jti"].is_a?(String) &&
      candidate["jti"].match?(UUID_PATTERN)

    validate_identity!(candidate, realm:)
    validate_scope!(candidate)
    validate_time!(candidate, now:)
  end

  def validate_identity!(candidate, realm:)
    prefix = SUBJECT_PREFIXES.fetch(realm)
    subject = candidate["sub"]
    raise Invalid, "command subject does not match its realm" unless subject.is_a?(String) &&
      subject.start_with?(prefix) && subject.delete_prefix(prefix).match?(PRINCIPAL_PATTERN)
    raise Invalid, "command actor must be an established subject" unless candidate["actor"].is_a?(String) &&
      candidate["actor"].match?(ACTOR_PATTERN)
    raise Invalid, "command reason must be a bounded categorical code" unless candidate["reason"].is_a?(String) &&
      candidate["reason"].match?(REASON_PATTERN)
  end

  def validate_scope!(candidate)
    case candidate["scope"]
    when "all_sessions"
      raise Invalid, "all-session command cannot name one session" if candidate.key?("session_public_id")
    when "session"
      target = candidate["session_public_id"]
      raise Invalid, "session command requires its exact public identifier" unless target.is_a?(String) &&
        target.match?(SESSION_PATTERN)
    else
      raise Invalid, "unsupported revocation scope"
    end
  end

  def validate_time!(candidate, now:)
    issued_at = candidate["iat"]
    expires_at = candidate["exp"]
    raise Invalid, "command lifetime must contain integer seconds" unless issued_at.is_a?(Integer) &&
      expires_at.is_a?(Integer)

    lifetime = expires_at - issued_at
    raise Invalid, "command lifetime must be positive and bounded" unless lifetime.positive? && lifetime <= MAX_LIFETIME
    raise Invalid, "command is not currently valid" unless issued_at <= now.to_i + CLOCK_SKEW &&
      expires_at > now.to_i - CLOCK_SKEW
  end
end
