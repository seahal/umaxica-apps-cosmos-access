# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/oidc_auth_admission_test_helper"

# The resend and cancel endpoints on the sign-up checkpoints. Every checkpoint
# controller routes DELETE to `cancel_from_explicit_step`, and the OTP
# checkpoints additionally route POST to a resend; neither is reachable from the
# happy path, so they are asserted here for the app surface.
class AuthSignUpCheckpointCancellationTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include OidcAuthAdmissionTestHelper

  self.fixture_table_names = []
  uses_transaction(
    "test_app_email_OTP_checkpoint_reissues_the_passcode_on_resend",
    "test_app_email_OTP_checkpoint_cancels_the_sign-up_ceremony_on_delete",
    "test_app_telephone_OTP_checkpoint_cancels_the_sign-up_ceremony_on_delete",
    "test_app_telephone_passkey_checkpoint_cancels_the_sign-up_ceremony_on_delete",
  )

  setup do
    @initial_client_ids = Client.pluck(:id)
    @initial_signup_ids = ClientSignUpFlow.pluck(:id)
    @initial_binding_ids = ClientAuthAdmissionBinding.pluck(:id)
    @initial_ceremony_ids = ClientAuthCeremonySession.pluck(:id)
    @initial_parent_ids = ClientOidcAuthorizationTransaction.pluck(:id)
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @previous_turnstile = [TurnstileVerifierStub.enabled, TurnstileVerifierStub.response]
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    ClientSignUpFlowStatus::DEFAULTS.each { |id| ClientSignUpFlowStatus.find_or_create_by!(id: id) }
    ClientSignUpFlowCleanupStatus::DEFAULTS.each { |id| ClientSignUpFlowCleanupStatus.find_or_create_by!(id: id) }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }

    bootstrap_auth_sign_up_admission!(surface: "app")
  end

  teardown do
    owners = Client.where.not(id: @initial_client_ids).to_a
    owner_ids = owners.map(&:id)
    flows = ClientSignUpFlow.where.not(id: @initial_signup_ids).to_a
    session_refs =
      flows.map do |flow|
        Digest::SHA256.hexdigest(JSON.generate(["email_sign_up", flow.public_id, flow.nonce_digest]))
      end
    ClientEmailCeremonyTransaction.where(session_ref: session_refs).delete_all
    telephone_refs = ClientTelephone.where(user_id: owner_ids).pluck(:public_id)
    ClientTelephoneCeremonyTransaction.where(telephone_candidate_ref: telephone_refs).delete_all
    ClientSignUpFlow.where(id: flows.map(&:id)).delete_all

    bindings = ClientAuthAdmissionBinding.where.not(id: @initial_binding_ids).to_a
    parent_ids = (bindings.map(&:authorization_transaction_id).compact - @initial_parent_ids).uniq
    ceremony_ids = bindings.flat_map do |binding|
      [binding.auth_ceremony_session_id, binding.admitted_auth_ceremony_session_id]
    end.compact.uniq
    ClientAuthAdmissionBinding.where(id: bindings.map(&:id)).delete_all
    ClientAuthCeremonySession.where(id: ceremony_ids - @initial_ceremony_ids).delete_all
    ClientOidcAuthorizationTransaction.where(id: parent_ids).delete_all
    ClientContactAuditOutbox.where(owner_ref: owners.map(&:public_id)).delete_all
    ClientEmail.where(user_id: owner_ids).delete_all
    ClientTelephone.where(user_id: owner_ids).delete_all
    ClientAccount.where(user_id: owner_ids).delete_all
    ClientAuthorityLock.where(client_id: owner_ids).delete_all
    Client.where(id: owner_ids).delete_all
  ensure
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
    TurnstileVerifierStub.enabled, TurnstileVerifierStub.response = @previous_turnstile
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "app email OTP checkpoint reissues the passcode on resend" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    get new_auth_app_sign_up_email_url(ri: "jp", host: host)
    csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    headers = { "Host" => host,
                "Origin" => "https://#{host}",
                "Sec-Fetch-Site" => "same-origin",
                "X-CSRF-Token" => csrf, }
    post auth_app_sign_up_email_url(ri: "jp", host: host),
         params: {
           user_email: { raw_address: "checkpoint_resend_app@example.com", confirm_policy: "1" },
           "cf-turnstile-response": "test",
         }, headers: headers

    assert_response :redirect
    registered = ClientEmail.order(:created_at).last
    first_sent_at = registered.otp_last_sent_at
    original_target = URI.parse(response.location)
    original_binding = Rack::Utils.parse_query(original_target.query).fetch("fb")
    transaction = ClientEmailCeremonyTransaction.find_by!(email_candidate_ref: registered.public_id)
    original_generation = transaction.otp_generation

    decision_time = first_sent_at + EmailOtpPolicy::SEND_COOLDOWN
    ClientEmail.stub(:database_now, decision_time) do
      ClientEmailCeremonyTransaction.stub(:database_now, decision_time) do
        post auth_app_sign_up_check_email_otp_url(ri: "jp", host: host, fb: original_binding), headers: headers
      end
    end

    assert_response :redirect
    assert_not_equal first_sent_at, registered.reload.otp_last_sent_at
    assert_not_equal original_generation, transaction.reload.otp_generation
  end

  test "app email OTP checkpoint cancels the sign-up ceremony on delete" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    get new_auth_app_sign_up_email_url(ri: "jp", host: host)
    csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    headers = { "Host" => host,
                "Origin" => "https://#{host}",
                "Sec-Fetch-Site" => "same-origin",
                "X-CSRF-Token" => csrf, }
    post auth_app_sign_up_email_url(ri: "jp", host: host),
         params: {
           user_email: { raw_address: "checkpoint_cancel_app@example.com", confirm_policy: "1" },
           "cf-turnstile-response": "test",
         }, headers: headers

    assert_response :redirect
    original_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    delete auth_app_sign_up_check_email_otp_url(ri: "jp", host: host, fb: original_binding), headers: headers

    assert_response :redirect
    assert_nil session[:auth_app_up_sequence_id]
  end

  test "app telephone OTP checkpoint cancels the sign-up ceremony on delete" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    get new_auth_app_sign_up_telephone_url(ri: "jp", host: host)
    csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    headers = { "Host" => host,
                "Origin" => "https://#{host}",
                "Sec-Fetch-Site" => "same-origin",
                "X-CSRF-Token" => csrf, }
    post auth_app_sign_up_telephone_url(ri: "jp", host: host),
         params: {
           user_telephone: { raw_number: "+819012340101", confirm_policy: "1", confirm_using_mfa: "1" },
           "cf-turnstile-response": "test",
         }, headers: headers

    assert_response :redirect
    original_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    delete auth_app_sign_up_check_telephone_otp_url(ri: "jp", host: host, fb: original_binding), headers: headers

    assert_response :redirect
    assert_nil session[:auth_app_up_sequence_id]
  end

  test "app telephone passkey checkpoint cancels the sign-up ceremony on delete" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! host
    get new_auth_app_sign_up_telephone_url(ri: "jp", host: host)
    csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
    headers = { "Host" => host,
                "Origin" => "https://#{host}",
                "Sec-Fetch-Site" => "same-origin",
                "X-CSRF-Token" => csrf, }
    post auth_app_sign_up_telephone_url(ri: "jp", host: host),
         params: {
           user_telephone: { raw_number: "+819012340111", confirm_policy: "1", confirm_using_mfa: "1" },
           "cf-turnstile-response": "test",
         }, headers: headers

    assert_response :redirect
    registration = session[:user_telephone_registration] || {}
    telephone = ClientTelephone.find_by!(public_id: registration[:public_id] || registration["public_id"])
    original_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")
    transaction = ClientTelephoneCeremonyTransaction.find_by!(telephone_candidate_ref: telephone.public_id)
    delivery =
      (enqueued_jobs + performed_jobs).reverse.find do |entry|
        next false unless entry.fetch(:job) == Outbound::SmsDeliveryJob

        encrypted = entry.fetch(:args).fetch(0).fetch("encrypted_payload")
        OutboundSensitivePayload.decrypt_sms_delivery(encrypted).fetch(:otp_binding)[3] == transaction.transaction_id
      end
    payload = OutboundSensitivePayload.decrypt_sms_delivery(delivery.fetch(:args).fetch(0).fetch("encrypted_payload"))
    patch auth_app_sign_up_check_telephone_otp_url(ri: "jp", host: host, fb: original_binding),
          params: {
            :user_telephone => { pass_code: payload.fetch(:otp_code) }, "cf-turnstile-response" => "test",
          }, headers: headers

    assert_predicate transaction.reload.otp_consumed_at, :present?
    get auth_app_sign_up_guard_telephone_url(ri: "jp", host: host, fb: original_binding), headers: headers

    delete auth_app_sign_up_check_telephone_passkey_url(ri: "jp", host: host, fb: original_binding), headers: headers

    assert_response :redirect
    assert_nil session[:auth_app_up_sequence_id]
  end
end
