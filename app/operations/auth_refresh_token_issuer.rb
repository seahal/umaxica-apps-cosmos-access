# typed: false
# frozen_string_literal: true

# Browser root refresh is independent of RP grant refresh. The realm is explicit and the
# caller builds the response inside the same transaction as the one-time rotation.
class AuthRefreshTokenIssuer
  Result =
    Data.define(:success, :token, :refresh_token, :previous_token, :reason, :response) do
      public

      def success? = success

      def [](key)
        case key.to_sym
        when :success then success
        when :token then token
        when :refresh_token then refresh_token
        when :previous_token then previous_token
        when :reason then reason
        when :response then response
        else raise KeyError, "unsupported refresh result key"
        end
      end

      def fetch(key)
        value = self[key]
        return value unless value.nil?

        raise KeyError, "key not found: #{key.inspect}"
      end
    end

  def self.call(refresh_token:, resource_type:, response_builder: nil, precondition: nil)
    new(refresh_token, resource_type, response_builder, precondition).call
  end

  public

  def initialize(refresh_token, resource_type, response_builder, precondition)
    @refresh_token = refresh_token
    @response_builder = response_builder
    @precondition = precondition
    case resource_type
    when "client"
      @token_class = ClientToken
      @device_class = ClientDeviceSession
      @owner = OpBaseAppRecord
    when "operator"
      @token_class = OperatorToken
      @device_class = OperatorDeviceSession
      @owner = OpBaseOrgRecord
    else
      raise ArgumentError, "unsupported browser refresh realm"
    end
  end

  def call
    parsed = @token_class.parse_refresh_token(@refresh_token)
    return failure(:invalid_format) unless parsed

    public_id, verifier = parsed
    @owner.connected_to(role: :writing) do
      @owner.transaction(requires_new: true) do
        token = @token_class.find_by(public_id: public_id)
        return failure(:token_not_found) unless token
        return failure(:invalid_digest, token: token) unless token.refresh_token_digest_matches?(verifier)

        device = @device_class.lock.find(token.device_session_id)
        token.lock!
        raise FlowConfigurationError, "browser refresh root device changed" unless token.device_session_id == device.id

        return failure(:inactive_token, token: token) unless device.usable?

        @precondition&.call(token)
        rotation = @token_class.rotate_refresh!(presented_refresh_digest: @token_class.digest_refresh_token(verifier))
        case rotation.fetch(:status)
        when :rotated
          replacement = rotation.fetch(:token)
          touch_oidc_connection!(replacement)
          response = @response_builder.call(replacement, rotation.fetch(:refresh_token)) if @response_builder
          Result.new(
            success: true, token: replacement, refresh_token: rotation.fetch(:refresh_token),
            previous_token: rotation.fetch(:previous_token), reason: nil, response: response,
          )
        when :replay
          stop_replayed_device!(device, rotation.fetch(:token))
          failure(:refresh_token_reuse_detected, token: rotation.fetch(:token))
        when :invalid
          failure(:inactive_token, token: rotation[:token])
        else
          raise RuntimeError, "unsupported browser rotation outcome"
        end
      end
    end
  end

  private

  def touch_oidc_connection!(token)
    connection = token.oidc_connection
    return unless connection

    now = @token_class.database_now
    connection.update!(last_used_at: now, updated_at: now)
  end

  # The Device Session is the root/grant boundary, including grants whose issuing root
  # is historical. Do not leave a rotated replacement or its grants usable after replay.
  def stop_replayed_device!(device, token)
    roots = @token_class.where(device_session_id: device.id).order(:id).lock.to_a
    roots.each do |root|
      OpAuthorityStopCommitter.stop_root(
        root: root, cause: "risk", principal_public_id: device.subject_public_id,
        authority_evidence_ref: "browser_refresh_reuse:#{token.public_id}",
      )
      raise OpAuthorityStopCommitter::Refused, "browser replay stop did not revoke its root" unless root.reload.revoked?
    end
    device.revoke!(reason: "refresh_token_reuse")
    case token
    when ClientToken
      SignRiskEmitter.emit("refresh_reuse_detected", user_id: token.subject_public_id, user_token_id: token.public_id)
    when OperatorToken
      SignRiskEmitter.emit("refresh_reuse_detected", staff_id: token.subject_public_id, user_token_id: token.public_id)
    else
      raise ArgumentError, "unsupported browser replay root"
    end
    RefreshTokenReuseActivityRecorder.call(token: token, result: "token_family_revoked")
    Rails.logger.warn(JitLogEvent.format("authentication.refresh.reuse_detected", outcome: "device_revoked"))
  end

  def failure(reason, token: nil)
    Result.new(success: false, token: token, refresh_token: nil, previous_token: nil, reason: reason, response: nil)
  end
  public_class_method :call
end
