# frozen_string_literal: true

# Starts a browser-facing Auth ceremony from an OIDC authorization transaction issued by Visa.
module OidcAuthAdmissionTestHelper
  AUTH_HOST_ENV = {
    "app" => "PUBLIC_AUTH_SERVICE_URL",
    "org" => "PUBLIC_AUTH_STAFF_URL",
  }.freeze

  def bootstrap_auth_sign_in_admission!(surface: "app", region: "jp")
    bootstrap_auth_admission!(surface:, intent: "sign_in", region:)
  end

  def bootstrap_auth_sign_up_admission!(surface: "app", region: "jp")
    raise ArgumentError, "Auth sign-up admission is available only on the App surface" unless surface.to_s == "app"

    bootstrap_auth_admission!(surface:, intent: "sign_up", region:)
  end

  def bootstrap_social_auth_admission!(auth:, auth_host:, intent: "sign_in")
    visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    visa = open_session
    visa.host!(visa_host)
    visa.https!
    authorization = social_oidc_authorization_params(intent)
    visa.get("/oauth/authorize", params: authorization, headers: social_oidc_navigation_headers("cross-site"))
    entry_uri = social_auth_entry_uri!(visa, auth_host)
    reference = Rack::Utils.parse_query(entry_uri.query.to_s).fetch("entry_ref")
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference:)
    auth.host!(auth_host)
    auth.https!
    auth.get(entry_uri.request_uri, headers: social_oidc_navigation_headers("cross-site"))
    follow_social_auth_admission!(auth:, visa:, auth_host:, visa_host:)
    @visa_browser = visa
    binding
  end

  private

  def social_oidc_authorization_params(intent)
    client = OidcClientRegistry.find!("core-app-jp")
    authorization = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      scope: "openid profile",
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: OidcTestEntry::CODE_CHALLENGE,
      code_challenge_method: "S256",
    }
    authorization[:prompt] = "create" if intent.to_s == "sign_up"
    authorization
  end

  def social_auth_entry_uri!(visa, auth_host)
    entry_uri = URI.parse(jump_rt_url_from_location_for_test(visa.response.location))
    raise RuntimeError, "Visa OIDC authorization did not redirect to Auth" unless entry_uri.host == auth_host

    entry_uri
  end

  def follow_social_auth_admission!(auth:, visa:, auth_host:, visa_host:)
    current = auth
    8.times do
      break unless current.response.redirect?

      target = URI.parse(jump_rt_url_from_location_for_test(current.response.location))
      receiver = social_auth_admission_receiver!(target.host, auth:, visa:, auth_host:, visa_host:)
      receiver.host!(target.host)
      receiver.https!
      receiver.get(target.request_uri, headers: social_oidc_navigation_headers("cross-site"))
      current = receiver
    end

    return if current.equal?(auth) && auth.response.status == 200

    raise RuntimeError, "OIDC admission did not finish on Auth"
  end

  def social_auth_admission_receiver!(host, auth:, visa:, auth_host:, visa_host:)
    case host
    when visa_host then visa
    when auth_host then auth
    else raise RuntimeError, "Unexpected OIDC admission host"
    end
  end

  def social_oidc_navigation_headers(site)
    {
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => site,
    }
  end

  def bootstrap_auth_admission!(surface:, intent:, region:)
    auth_host = ENV.fetch(AUTH_HOST_ENV.fetch(surface.to_s))
    host!(auth_host)
    https!

    issuance = OidcTestEntry.issue!(
      surface:, intent:, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    entry_path = public_send("auth_#{surface}_#{intent}_path", ri: region)
    admit_auth_ceremony_entry!(entry_path, reference: issuance.reference)

    raise RuntimeError, "Auth OIDC admission did not issue an entry redirect" unless response.status == 303

    target = URI.parse(response.location)
    raise RuntimeError, "Auth OIDC admission redirected outside Auth" if target.host && target.host != auth_host

    get(target.request_uri, headers: navigation_headers)
    raise RuntimeError, "Auth OIDC admission did not render its entry page" unless response.successful?

    self
  end

  def navigation_headers
    {
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
    }
  end

  def complete_social_oidc_visa_result!(target:, visa_browser:, visa_host:)
    callback_uri = social_oidc_visa_callback_uri!(
      target:, visa_browser:, visa_host:,
    )
    callback_parameters = Rack::Utils.parse_query(callback_uri.query.to_s)
    registered_callback = OidcClientRegistry.find!("core-app-jp").redirect_uris_by_realm.fetch("client").first
    expected_callback = URI.parse(registered_callback)

    assert_predicate callback_parameters["code"], :present?
    assert_predicate callback_parameters["state"], :present?
    assert_equal [expected_callback.host, expected_callback.path], [callback_uri.host, callback_uri.path]
    callback_uri
  end

  def social_oidc_visa_callback_uri!(target:, visa_browser:, visa_host:)
    unless target.host == visa_host && target.path == "/oidc/result"
      raise RuntimeError, "unexpected Visa result target"
    end

    transaction_ref = Rack::Utils.parse_query(target.query.to_s).fetch("transaction_ref")
    transaction = ClientOidcAuthorizationTransaction.find_by!(transaction_id: transaction_ref)
    @social_auth_oidc_parent = transaction
    actor = Client.find_by!(public_id: transaction.actor_ref)
    roots_before = ClientToken.where(user_id: actor.id).count

    visa_browser.host!(visa_host)
    visa_browser.https!
    visa_browser.get(target.request_uri, headers: social_visa_navigation_headers(visa_host))
    unless visa_browser.response.status == 200
      raise RuntimeError, "Visa result did not render its POST continuation"
    end

    form = Nokogiri::HTML(visa_browser.response.body).at_css("form#visa-authorization-continuation-form")
    raise RuntimeError, "Visa result continuation form is missing" unless form

    visa_browser.post(
      form["action"],
      params: form.css("input[name]").to_h { |input| [input["name"], input["value"]] },
      headers: {
        "Host" => visa_host,
        "Origin" => "https://#{visa_host}",
        "Sec-Fetch-Site" => "same-origin",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
      },
    )
    raise RuntimeError, "Visa result continuation POST did not redirect" unless visa_browser.response.redirect?

    assert_equal roots_before + 1, ClientToken.where(user_id: actor.id).count
    resolve_social_oidc_callback_uri(visa_browser.response.location, visa_host:)

  end

  def resolve_social_oidc_callback_uri(location, visa_host:)
    callback_uri = URI.parse(location)
    jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host
    return callback_uri unless callback_uri.host == jump_host

    result_token = Rack::Utils.parse_query(callback_uri.query).fetch("rt")
    issuer = JitSecurityJwtRegistry.surface("VISA_APP")
    payload, = JWT.decode(
      result_token,
      JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid),
      true,
      algorithms: ["ES384"],
      verify_iss: true,
      iss: "https://#{visa_host}",
      verify_aud: true,
      aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    URI.parse(payload.fetch("url"))
  end

  def social_visa_navigation_headers(visa_host)
    {
      "Host" => visa_host,
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
  end
end
