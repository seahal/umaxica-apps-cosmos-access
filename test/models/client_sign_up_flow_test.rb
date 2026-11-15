# frozen_string_literal: true

require "test_helper"

class ClientSignUpFlowTest < ActiveSupport::TestCase
  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::ClientSignUpFlow)
  end

  # R-AU-46: a required reference association with no row must surface as the ordinary
  # belongs_to validation failure in both locales, not as `I18n::MissingTranslationData`
  # for `activerecord.attributes.client_sign_up_flow.cleanup_status`.
  test "a missing cleanup-status reference renders its validation failure in both locales" do
    flow =
      ClientSignUpFlow.new(
        auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
        principal_id: 0, entry_method: "email", step: "checkpoint",
        nonce_digest: ClientSignUpFlow.digest_nonce("ra46-browser"),
        status_id: ClientSignUpFlowStatus::STARTED, state: "STARTED",
        cleanup_status_id: ClientSignUpFlowCleanupStatus.maximum(:id).to_i + 1,
      )

    [:en, :ja].each do |locale|
      I18n.with_locale(locale) do
        flow.valid?

        assert_includes flow.errors.messages, :cleanup_status,
                        "the missing reference row must fail the belongs_to validation in #{locale}"
        messages = flow.errors.full_messages_for(:cleanup_status)

        assert messages.join(" ").exclude?("Translation missing"),
               "the cleanup-status failure must render from the real translations in #{locale}"
      end
    end
  end

  test "the reported cleanup-status attribute has a translated name in both locales" do
    [:en, :ja].each do |locale|
      I18n.with_locale(locale) do
        assert_not(
          ClientSignUpFlow.human_attribute_name(:cleanup_status).exclude?(
            (locale == :en) ? "Cleanup status" : "片付け状態",
          ),
        )
      end
    end
  end

  # BL-22/REQ-CURFEW 5: a sign-up Flow is created after its Admission Binding, so the Binding's
  # curfew, not the Flow's own TTL, ends the attempt; the code caps `expires_at` at creation and
  # this closes the old "the Flow keeps an independent expiry" discrepancy from the code side.
  test "a newly created sign-up flow is capped at its binding curfew" do
    binding = SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow)
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding,
      principal_id: 0, entry_method: "email", step: "cancelled",
      nonce_digest: ClientSignUpFlow.digest_nonce("bl22-browser"),
      status_id: ClientSignUpFlowStatus::CANCELLED,
      cleanup_status_id: ClientSignUpFlowCleanupStatus::PENDING,
    )

    assert_predicate binding.reload.curfew_at, :present?,
                     "the Admission Binding must carry the durable curfew the cap reads"
    assert_equal binding.curfew_at.to_i, flow.reload.expires_at.to_i,
                 "the Flow's expiry must not outlive its Admission Binding curfew"
  end
  test "historical principal data remains mutable for local terminal lifecycle without Zenith" do
    binding = SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow)
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding, principal_id: 9_876_543, entry_method: "email", step: "start",
      nonce_digest: "c" * 64, status_id: ClientSignUpFlowStatus::STARTED,
      cleanup_status_id: ClientSignUpFlowCleanupStatus::IDLE,
    )
    flow.update!(return_to: "/history")
    flow.cancel_sign_up!

    assert_predicate flow.reload, :sign_up_cancelled?
    assert_equal 9_876_543, flow.principal_id
    assert_equal "/history", flow.return_to
    assert_not_nil flow.cancelled_at
    # Historical scalar identity does not authorize a cross-store ORM lookup.
    assert_nil ClientSignUpFlow.reflect_on_association(:principal)
  end

  test "admission binding deletion is restricted while sign-up lifecycle history refers to it" do
    client = OidcClientRegistry.find!("base-app-ww")
    parameters = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      scope: "openid profile",
      prompt: "create",
    }
    browser_nonce = SecureRandom.urlsafe_base64(32)
    issuance = OidcAuthorizationTransactionCoordinator.issue_with_handoff!(
      surface: "app", intent: "sign_up", params: parameters,
      base_browser_nonce: browser_nonce, base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
      surface: "app", reference: issuance.handoff.reference,
    )
    ceremony_session_class = binding.class.auth_admission_session_class
    attached_session, raw_auth_sid = ceremony_session_class.issue!
    binding.attach_auth_session!(auth_session: attached_session, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(
        surface: "app", entry_ref: issuance.handoff.reference, nonce: browser_nonce,
      ),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.handoff.reference,
      surface: "app",
      expected_intent: "sign_up",
      binding: binding,
      raw_auth_sid: raw_auth_sid,
    )
    admitted_session, = ceremony_session_class.rotate_and_admit!(
      admission_purpose: "authentication_handoff",
      previous_raw_sid: raw_auth_sid,
      authorization_transaction_ref: issuance.transaction.transaction_id,
    )
    binding.redeem!(auth_session: attached_session, admitted_auth_session: admitted_session)
    ClientSignUpFlow.create!(
      auth_admission_binding: binding,
      principal_id: 0,
      entry_method: "email",
      step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce("sign-up-binding-retention"),
      status_id: ClientSignUpFlowStatus::STARTED,
      state: "STARTED",
      cleanup_status_id: ClientSignUpFlowCleanupStatus::IDLE,
    )

    assert_raises(ActiveRecord::DeleteRestrictionError) { binding.destroy! }
    assert ClientSignUpFlow.exists?(auth_admission_binding_id: binding.id)
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        binding.class.transaction(requires_new: true) { binding.delete }
      end
    assert_instance_of PG::RestrictViolation, error.cause
    assert ClientSignUpFlow.exists?(auth_admission_binding_id: binding.id)
  end

  test "registration reconciliation and new forward progress require Governance authority" do
    binding = SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow)
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding, principal_id: 9_876_543, entry_method: "email", step: "start",
      nonce_digest: "d" * 64, status_id: ClientSignUpFlowStatus::STARTED,
      cleanup_status_id: ClientSignUpFlowCleanupStatus::IDLE,
    )
    before = flow.reload.attributes

    assert_raises(GovernanceLookupUnavailableError) { flow.registration_completion }
    assert_raises(GovernanceLookupUnavailableError) { flow.lock_registration_parent! }
    assert_raises(GovernanceLookupUnavailableError) { flow.require_registration_authority! }
    assert_raises(GovernanceLookupUnavailableError) { flow.advance_sign_up_to_contact! }
    assert_raises(GovernanceLookupUnavailableError) { flow.complete_sign_up! }
    assert_equal before, flow.reload.attributes
  end
end
