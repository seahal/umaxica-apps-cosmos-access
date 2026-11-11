# frozen_string_literal: true

# Exercises the browser-facing RP -> Auth admission transport through its current GET entry and
# Visa redirect contract.
module AuthCeremonyEntryHelper
  # An authorization-transaction entry GET relays automatically to /ceremony_bindings, which
  # attaches the Auth session and hands the browser to Visa. Applying the model transition directly
  # here isolates the Auth leaf; the Visa receiver has its own HTTP boundary.
  def admit_auth_ceremony_entry!(path, reference:, params: {}, browser: self, base_token: nil, browser_digest: nil)
    binding = attach_auth_ceremony_entry!(path, reference:, params:, browser:)
    binding.confirm_base!(base_token:, browser_digest: browser_digest || binding.base_browser_digest)
    browser.get(
      path, params: params.merge(entry_ref: reference), headers: {
        "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
      },
    )
    raise RuntimeError, "auth entry did not redeem the admission (HTTP #{browser.response.status})" unless
      browser.response.status == 303

    browser.response
  end

  def attach_auth_ceremony_entry!(path, reference:, params: {}, browser: self)
    browser.get(
      path, params: params.merge(entry_ref: reference), headers: {
        "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
      },
    )

    raise RuntimeError, "auth entry did not relay to ceremony_bindings (HTTP #{browser.response.status})" unless
      browser.response.status == 303 && URI.parse(browser.response.location).path == "/ceremony_bindings"

    browser.get(browser.response.location, headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" })
    confirmation_uri = URI.parse(browser.response.location)
    binding = [ClientAuthAdmissionBinding, OperatorAuthAdmissionBinding]
      .lazy.filter_map { |model| model.find_by(entry_ref: reference) }.first
    raise RuntimeError, "admission binding is missing" unless binding

    visa_realm = binding.is_a?(ClientAuthAdmissionBinding) ? :service : :staff
    expected_visa_host = Rails.configuration.x.boot_config.fetch(:hosts).public_send("visa_#{visa_realm}").host

    raise RuntimeError, "ceremony binding did not hand off to Visa (HTTP #{browser.response.status})" unless
      browser.response.status == 303 && confirmation_uri.host == expected_visa_host &&
        confirmation_uri.path == "/ceremony_bindings/#{binding.confirmation_ref}/confirmation"

    binding
  end
end
