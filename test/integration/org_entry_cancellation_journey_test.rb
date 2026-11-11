# frozen_string_literal: true

require "test_helper"

class OrgEntryCancellationJourneyTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @previous_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    @visa_host = visa_host_for_test_surface(:org)
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_forgery_protection
  end

  [
    ["method selection", "/sign/in", "cancel_form"],
    ["emergency Passkey", "/sign/in/emergency/passkey/new", "parent_cancel"],
  ].each do |label, path, cancel_key|
    test "ORG #{label} Cancel protects CSRF and returns the OIDC denial through Visa" do
      visa_browser = open_session
      visa_browser.host!(@visa_host)
      visa_browser.https!
      client = OidcClientRegistry.find!("core-org-jp")
      visa_browser.get(
        "/oauth/authorize", params: {
          response_type: "code",
          client_id: client.client_id,
          redirect_uri: client.redirect_uris_by_realm.fetch("operator").first,
          scope: "openid profile",
          state: SecureRandom.urlsafe_base64(32),
          nonce: SecureRandom.urlsafe_base64(32),
          code_challenge: OidcTestEntry::CODE_CHALLENGE,
          code_challenge_method: "S256",
        }, headers: {
          "Host" => @visa_host,
          "Sec-Fetch-Mode" => "navigate",
          "Sec-Fetch-Dest" => "document",
          "Sec-Fetch-Site" => "cross-site",
        },
      )

      assert_equal 303, visa_browser.response.status
      visa_session_cookie_name = JitSessionCookieConfig.cookie_key(
        force_secure: JitSessionCookieConfig.force_secure?,
      )

      assert_predicate visa_browser.cookies[visa_session_cookie_name].to_s, :present?
      entry = URI.parse(jump_rt_url_from_location_for_test(visa_browser.response.location))

      assert_equal @auth_host, entry.host
      entry_ref = Rack::Utils.parse_query(entry.query).fetch("entry_ref")
      host! @auth_host
      https!
      auth_headers = {
        "Host" => @auth_host,
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
        "Sec-Fetch-Site" => "cross-site",
      }
      get(auth_org_sign_in_path(ri: "jp"), params: { entry_ref: entry_ref }, headers: auth_headers)

      assert_response :see_other
      get(response.location, headers: auth_headers)
      confirmation = URI.parse(jump_rt_url_from_location_for_test(response.location))

      assert_equal @visa_host, confirmation.host
      host! @visa_host
      visa_headers = {
        "Host" => @visa_host,
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
        "Sec-Fetch-Site" => "cross-site",
      }
      visa_browser.host!(@visa_host)
      visa_browser.get(confirmation.request_uri, headers: visa_headers)

      assert_equal 303, visa_browser.response.status
      entry_result = URI.parse(jump_rt_url_from_location_for_test(visa_browser.response.location))

      assert_equal @auth_host, entry_result.host
      host! @auth_host
      get(entry_result.request_uri, headers: auth_headers)
      next_entry = URI.parse(response.location) if response.redirect?
      if next_entry
        assert_includes [nil, @auth_host], next_entry.host
        get(next_entry.request_uri, headers: auth_headers)
      end

      assert_response :success, "Auth ceremony entry returned HTTP #{response.status} at #{entry_result.path}"
      auth_navigation_headers = {
        "Host" => @auth_host,
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
        "Sec-Fetch-Site" => "same-origin",
      }
      get(path, params: { ri: "jp" }, headers: auth_navigation_headers)

      assert_response :success
      cancel = inertia_props.fetch(cancel_key)
      if cancel_key == "parent_cancel"
        assert_equal I18n.t("actions.back"), inertia_props.fetch("back_link").fetch("label")
        assert_equal "/sign/in", URI.parse(inertia_props.fetch("back_link").fetch("href")).path
      end

      assert_predicate cancel, :present?
      assert_equal "/sign/cancellation", URI.parse(cancel.fetch("action")).path
      csrf = response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
      ceremony = OperatorAuthCeremonySession.find_active_by_raw_sid(cookies[cookie_name])
      parent = OperatorOidcAuthorizationTransaction.find_by!(transaction_id: ceremony.authorization_transaction_ref)
      before = [ceremony.attributes, parent.attributes]
      token_count = OperatorToken.count
      headers = auth_navigation_headers.merge("Origin" => "https://#{@auth_host}")
      post(cancel.fetch("action"), headers: headers)

      assert_response :unprocessable_content
      assert_equal before, [ceremony.reload.attributes, parent.reload.attributes]
      post(cancel.fetch("action"), params: { authenticity_token: csrf }, headers: headers)

      assert_response :see_other
      assert_predicate ceremony.reload, :cancelled?
      assert_predicate parent.reload, :canceled?
      assert_predicate cookies[cookie_name], :blank?
      assert_visa_cancellation_result(visa_browser:, location: response.location)
      assert_equal token_count, OperatorToken.count
    end
  end

  private

  def assert_visa_cancellation_result(visa_browser:, location:)
    target = URI.parse(jump_rt_url_from_location_for_test(location))

    assert_equal @visa_host, target.host
    visa_navigation_headers = {
      "Host" => @visa_host,
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "same-origin",
    }

    assert_predicate visa_browser.cookies[JitSessionCookieConfig.cookie_key(
      force_secure: JitSessionCookieConfig.force_secure?,
    )].to_s, :present?
    visa_browser.host!(@visa_host)
    visa_browser.get(target.request_uri, headers: visa_navigation_headers)

    assert_equal 200, visa_browser.response.status,
                 "Visa cancellation continuation must render for its bound OP session"
    form = visa_browser.response.parsed_body.at_css("form#visa-authorization-continuation-form")

    assert form, "Visa must render the cancellation continuation POST"
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    visa_browser.post(
      form["action"], params: fields,
                      headers: visa_navigation_headers.merge("Origin" => "https://#{@visa_host}"),
    )

    assert_equal 303, visa_browser.response.status
    callback = URI.parse(jump_rt_url_from_location_for_test(visa_browser.response.location))
    redirect_uri = URI.parse(
      OidcClientRegistry.find!("core-org-jp").redirect_uris_by_realm.fetch("operator").first,
    )

    assert_equal [redirect_uri.host, redirect_uri.path], [callback.host, callback.path]
    assert_equal({ "error" => "access_denied" }, Rack::Utils.parse_query(callback.query).slice("error", "code"))
  end
end
