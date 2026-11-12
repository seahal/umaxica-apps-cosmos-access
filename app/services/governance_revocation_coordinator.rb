# frozen_string_literal: true

class GovernanceRevocationCoordinator
  class Uncommitted < StandardError; end

  class << self
    public

    def call(token:, realm:)
      new(token:, realm:).call
    end
  end

  def initialize(token:, realm:)
    @token = token
    @realm = realm
  end

  public

  def call
    issuer, jwks_url, resource_type = trust_configuration
    audience = OidcIssuer.for_resource_type(resource_type)
    verifier = GovernanceRevocationCommandVerifier.new(issuer:, jwks_url:, audience:, realm:)
    command = verifier.verify(token)
    owner = GovernanceRevocationCommand::REALMS.fetch(realm).fetch(:owner)
    raise Uncommitted, "command receiver requires its own commit boundary" if owner.lease_connection.transaction_open?

    receipt = GovernanceRevocationCommand.call(command:)
    raise Uncommitted, "command receipt did not commit" unless receipt.persisted? &&
      !owner.lease_connection.transaction_open?

    GovernanceRevocationAcknowledgementCodec.encode(
      command_id: receipt.command_id, realm:, issuer: audience, audience: receipt.issuer,
    )
  end

  private

  attr_reader :token, :realm

  def trust_configuration
    case realm
    when "app"
      [ENV.fetch("GOVERNANCE_APP_REVOCATION_ISSUER"), ENV.fetch("GOVERNANCE_APP_REVOCATION_JWKS_URL"), "client"]
    when "org"
      [ENV.fetch("GOVERNANCE_ORG_REVOCATION_ISSUER"), ENV.fetch("GOVERNANCE_ORG_REVOCATION_JWKS_URL"), "operator"]
    else
      raise ArgumentError, "unsupported revocation realm"
    end
  end
end
