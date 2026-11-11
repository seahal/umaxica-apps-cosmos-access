# typed: false
# frozen_string_literal: true

# Builds the shared Inertia props that the React surface layout renders as page chrome.
#
# Before the Inertia migration this data was read straight out of the ERB layout by helpers
# (`current_banner_for`, `t(...)`, `*_url`). A React layout cannot reach any of that, so the chrome
# becomes a serialized prop shared by every Inertia response of the surface. Everything that is a
# server responsibility stays here: translation, route generation, the banner query, and the
# decision about which navigation a visitor is allowed to see.
#
# The shared payload is per surface by construction: each including controller declares its own
# family, surface and banner domain, and `inertia_share` runs in that controller's instance, so one
# surface can never publish another surface's chrome.
module SurfaceChrome
  extend ActiveSupport::Concern

  # Chrome differs between Auth and Visa; `banner_domain` selects the banner stream, and nil opts
  # out of banner lookup for the Visa protocol pages.
  FAMILY_CHROME = {
    "auth" => { family_label: nil, banner_domain: :sign },
    "visa" => { family_label: "VISA", banner_domain: nil },
  }.freeze

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    inertia_share chrome: -> { surface_chrome }
    inertia_share clear_history: -> { session[:inertia_clear_history] == true }
  end

  private

  def chrome_configuration
    @chrome_configuration ||=
      begin
        family, surface = controller_path.to_s.split("/").first(2)
        defaults =
          FAMILY_CHROME.fetch(family) do
            raise ArgumentError,
                  "#{self.class.name} renders Inertia pages from an unknown family #{family.inspect}; " \
                  "add its chrome to SurfaceChrome::FAMILY_CHROME rather than rendering chromeless pages"
          end

        defaults.merge(family: family, surface: surface).freeze
      end
  end

  def surface_chrome
    configuration = chrome_configuration

    chrome = {
      family_label: configuration.fetch(:family_label),
      surface: configuration.fetch(:surface),
      brand: chrome_brand,
      banner: chrome_banner(configuration.fetch(:banner_domain)),
      restricted_mode: chrome_restricted_mode,
      footer_navigation: nil,
      cookie_controls: nil,
      theme_controls: nil,
      account_navigation: chrome_account_navigation,
      copyright: chrome_copyright,
    }
    chrome
  end

  # Restricted Mode (Emergency Access) is a property of the session, not of a
  # page, so it is published once here and rendered by the persistent layout.
  # No screen can omit the indicator, because no screen supplies it: a page that
  # forgets about Emergency Access still renders inside the same chrome.
  #
  # The decision comes from the session row the request authenticated against --
  # the same authority that mints the `authn_ctx` claim -- never from a request
  # parameter, a cookie the browser can write, or page state.
  #
  # Hiding navigation is not authorization. The banner and the trimmed
  # navigation are there so the operator understands what they are looking at;
  # the server denies the unavailable operations regardless
  # (docs/security/org-emergency-access.md).
  def chrome_restricted_mode
    return nil if chrome_configuration.fetch(:family) == "visa"

    return nil unless chrome_authentication_context.standby?

    scope = "layouts.shared.restricted_mode"
    {
      label: chrome_t("#{scope}.label"),
      description: chrome_t("#{scope}.description"),
    }
  end

  # A surface with no authenticated session, and a surface whose sessions cannot
  # carry a context at all, are both Normal by construction rather than by a
  # lookup that could be made to answer otherwise.
  def chrome_authentication_context
    return AuthenticationContextValue.normal unless respond_to?(:current_session, true)

    session_record = current_session
    return AuthenticationContextValue.normal if session_record.blank?

    session_record.authentication_context_value
  end

  def chrome_brand
    family = chrome_configuration.fetch(:family)
    if family == "visa"
      surface = chrome_configuration.fetch(:surface)
      return {
        name: ENV.fetch("BRAND_NAME"),
        href: chrome_url("visa_#{surface}_oidc_logout_path"),
      }
    end

    return { name: ENV.fetch("BRAND_NAME"), href: nil } if family == "auth"

    raise ArgumentError, "unsupported chrome family: #{family.inspect}"
  end

  # The banner query previously ran inside a layout partial on every response. It stays server-side
  # but moves out of the view, because a React layout cannot reach a Rails helper.
  def chrome_banner(domain)
    return nil if domain.blank?

    banner = CurrentBannerQuery.call(
      tld: chrome_configuration.fetch(:surface).to_sym,
      domain: domain,
      region: :global,
    )
    return nil if banner.blank?

    { title: banner.title.presence, body: banner.body }
  end

  # Auth and Visa host ceremonies, not RP navigation. They publish no cross-surface account links.
  def chrome_account_navigation
    nil
  end

  def chrome_copyright
    "© #{Time.zone.today.year} #{ENV.fetch("BRAND_NAME")}"
  end

  # Keys are composed from the surface, so they cannot be literals at the call site; passing the
  # composed key through here keeps every translation lookup in one place.
  def chrome_t(key, **)
    t(key, **)
  end

  def chrome_url(helper, options = nil)
    options.present? ? public_send(helper, options) : public_send(helper)
  end
end
