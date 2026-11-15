# typed: false
# frozen_string_literal: true

class RefreshTokenReuseActivityRecorder
  def self.call(token:, result:)
    new(token, result).call
  end
  public_class_method :call

  public

  def initialize(token, result)
    @token = token
    @result = result
  end

  def call
    audit_class, event_id, actor_type, actor_id, surface = audit_target

    context = {
      token_family_id: @token.refresh_token_family_id,
      generation: @token.refresh_token_generation,
      surface: surface,
      result: @result,
    }.compact
    AuthenticationAuditWriter.write_reference(
      audit_class, event_id,
      subject_type: actor_type, subject_id: actor_id.to_s,
      actor_type: actor_type, actor_id: actor_id.to_s, context: context,
    )
  end

  private

  def audit_target
    case @token
    when ClientToken
      [
        ClientChronicle,
        ClientChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED,
        "Client",
        @token.subject_public_id,
        "app",
      ]
    when OperatorToken
      [
        OperatorChronicle,
        OperatorChronicleEvent::REFRESH_TOKEN_REUSE_DETECTED,
        "Operator",
        @token.subject_public_id,
        "org",
      ]
    else
      raise ArgumentError, "unsupported refresh token class: #{@token.class.name}"
    end
  end
end
