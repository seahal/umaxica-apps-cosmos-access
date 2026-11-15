# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentityCeremonyCandidateIntegrityTest < ActiveSupport::TestCase
  test "APP passkey candidate integrity is bound to every retained key field" do
    attributes = {
      webauthn_id: "credential-reference",
      public_key: "credential-public-key",
      sign_count: 4,
      description: "Platform passkey",
      transports: ["internal"],
      metadata: { "backup_eligible" => false },
    }
    candidate = IdentityPasskeyCeremonyCandidate.new(
      **attributes,
      digest: IdentityPasskeyCeremonyCandidate.digest_for(**attributes),
    )

    assert_match(/\A[0-9a-f]{64}\z/, candidate.material_digest)
    assert_predicate candidate, :material_intact?

    candidate.sign_count = 5

    assert_not_predicate candidate, :material_intact?
  end

  test "ORG passkey candidate integrity is bound to every retained key field" do
    attributes = {
      webauthn_id: "operator-credential-reference",
      public_key: "operator-credential-public-key",
      sign_count: 8,
      description: "Operator passkey",
      transports: ["usb"],
      metadata: { "backup_eligible" => true },
    }
    candidate = OperatorPasskeyCeremonyCandidate.new(
      **attributes,
      digest: OperatorPasskeyCeremonyCandidate.digest_for(**attributes),
    )

    assert_match(/\A[0-9a-f]{64}\z/, candidate.material_digest)
    assert_predicate candidate, :material_intact?

    candidate.public_key = "substituted-public-key"

    assert_not_predicate candidate, :material_intact?
  end

  test "social candidate references accept the retained formats and refuse malformed values" do
    assert IdentitySocialCeremonyCandidate.valid_reference?(PublicId.generate)
    assert IdentitySocialCeremonyCandidate.valid_reference?("550e8400-e29b-41d4-a716-446655440000")
    assert_not IdentitySocialCeremonyCandidate.valid_reference?("")
    assert_not IdentitySocialCeremonyCandidate.valid_reference?("not-a-reference")
    assert_not IdentitySocialCeremonyCandidate.valid_reference?(123)
  end
end
