# frozen_string_literal: true

class GovernanceRevocationAcknowledgementCodec
  TOKEN_TYPE = "governance-revocation-ack+jwt"

  class << self
    public

    def encode(command_id:, realm:, issuer:, audience:, now: Time.current)
      issuer_id =
        case realm
        when "app" then "surface:VISA_APP"
        when "org" then "surface:VISA_ORG"
        else raise ArgumentError, "unsupported acknowledgement realm"
        end
      payload = {
        "iss" => issuer,
        "aud" => audience,
        "iat" => now.to_i,
        "exp" => now.to_i + GovernanceRevocationCommandValue::MAX_LIFETIME,
        "jti" => JitSecurityJwtJtiGenerator.generate,
        "command_id" => command_id,
        "status" => "completed",
      }
      JitSecurityJwtKeyring.encode(payload, typ: TOKEN_TYPE, issuer_id:)
    end
  end
end
