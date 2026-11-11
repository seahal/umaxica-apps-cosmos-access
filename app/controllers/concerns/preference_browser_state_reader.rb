# typed: false
# frozen_string_literal: true

require "jwt"

# Read-only resolution for Auth's browser-bound anonymous Preference state. The API shares the
# same active-row, expiry, receipt, binding, and realm checks as the page projection.
module PreferenceBrowserStateReader
  extend ActiveSupport::Concern

  CONSENT_RECEIPT_CLASSES = {
    "app" => AppPreferenceConsentReceipt,
    "org" => OrgPreferenceConsentReceipt,
  }.freeze
  BROWSER_BINDING_CLASSES = {
    "app" => AppPreferenceBrowserBinding,
    "org" => OrgPreferenceBrowserBinding,
  }.freeze

  private

  def cookie_consent_state
    return @cookie_consent_state_override if @cookie_consent_state_override

    return anonymous_realm_cookie_consent_state if anonymous_preference_claim_shape?(preference_class)

    raise PreferenceBase::ResolutionError, "unsupported Preference consent model"
  end

  def anonymous_realm_cookie_consent_state
    @cookie_consent_decision_available = false
    empty = { consented: false, functional: false, performant: false, targetable: false }

    family, surface = controller_path.split("/", 3)
    raise PreferenceBase::ResolutionError, "unsupported Preference consent reader: #{family.inspect}" unless
      family == "auth" && surface == preference_realm_name

    payload = decoded_preference_payload
    public_id = PreferenceToken.extract_public_id(payload)
    return empty if public_id.blank?

    realm = preference_realm_name
    prefix = realm.capitalize
    preference_class.connection_class_for_self.connected_to(role: :writing, prevent_writes: true) do
      preference = preference_class.find_by(public_id:, status_id: preference_class::ACTIVE_STATUS_ID)
      now = preference_class.database_now
      return empty unless preference&.issuance_active_at?(now:) && now.to_i < payload.fetch("exp")

      cookie = PreferenceClassRegistry.cookie_class(prefix).find_by(preference_id: preference.id)
      return empty unless cookie

      receipt = matching_browser_consent_receipt(realm: realm, preference: preference)
      @cookie_consent_decision_available = receipt.present?
      return empty unless @cookie_consent_decision_available

      readable_cookie_state(cookie)
    end
  rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
    Rails.logger.error(
      JitLogEvent.format("preference.consent.read_failed", realm:, error_class: e.class.name),
    )
    raise PreferenceBase::ResolutionError, "Preference consent state is unavailable"
  end

  def matching_browser_consent_receipt(realm:, preference:)
    receipt = CONSENT_RECEIPT_CLASSES.fetch(realm).find_by(preference_id: preference.id)
    binding = BROWSER_BINDING_CLASSES.fetch(realm).find_by(preference_id: preference.id)
    return unless receipt && binding
    return unless PreferenceBrowserBinding.matches?(cookies[PreferenceBrowserBinding::COOKIE_NAME], binding.digest)

    receipt
  end

  # SSOT decode point.
  def decode_and_verify_preference_jwt(jwt)
    payload = decode_matching_access_token(jwt)
    return payload if payload.is_a?(Hash)

    Rails.logger.info(I18n.t("errors.preference.cookie.invalid_access_token"))
    nil
  end

  def decoded_preference_payload
    @decoded_preference_payload ||=
      begin
        jwt = matching_access_token_value
        decode_and_verify_preference_jwt(jwt)
      end
  end
end
