# typed: false
# frozen_string_literal: true

require "test_helper"

# Provider fixtures exercise the application contract, not live Google or Apple behavior.
class SocialLoginSocTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  private

  def admit_social_auth!(browser, intent:, visa_browser: nil)
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    browser.host!(auth_host)
    browser.https!
    base_browser_nonce = SecureRandom.urlsafe_base64(32)
    issuance = OidcTestEntry.issue!(surface: "app", intent:, base_browser_nonce:, base_token: nil)
    if visa_browser
      visa_browser.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] = base_browser_nonce
    end
    entry_path = (intent == "sign_up") ? auth_app_sign_up_path(ri: "jp") : auth_app_sign_in_path(ri: "jp")
    admit_auth_ceremony_entry!(entry_path, reference: issuance.reference, browser:)
    target = URI.parse(browser.response.location)
    raise RuntimeError, "Auth admission redirected outside Auth" if target.host && target.host != auth_host

    browser.get(
      target.request_uri, headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" },
    )
    raise RuntimeError, "Auth admission did not render its entry page" unless browser.response.successful?

    issuance
  end

  def social_admission_binding_for(browser)
    ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(browser.cookies["auth_sid"])
    ClientAuthAdmissionBinding.find_by!(admitted_auth_ceremony_session_id: ceremony.id)
  end

  def set_social_provider_fixture(browser, provider, subject)
    OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
      provider:, uid: subject, info: { name: "SOC provider fixture" },
      credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
      extra: { id_info: { nonce: browser.session[:social_auth_nonce] } },
    )
  end

  public

  setup do
    @previous_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    OmniAuth.config.test_mode = true
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous_protection
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  %w(google apple).each do |provider|
    if provider == "apple"
      test "SOC-5: Apple linked reserved Client is refused without guidance or authority" do
        sign_up = false
        subject = "soc5-#{SecureRandom.hex(8)}"
        actor = Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          status_id: ClientStatus::RESERVED, birthdate: "2000-01-01",
        )
        ClientAppleIdentity.create!(
          user: actor, uid: subject, provider: "apple", status_id: ClientAppleIdentityStatus::ACTIVE,
        )
        auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        auth = open_session
        auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
        admit_social_auth!(auth, intent: "sign_in")

        assert_equal [200, "/sign/in"], [auth.response.status, auth.request.path]
        binding = ClientAuthAdmissionBinding.find_by!(
          admitted_auth_ceremony_session_id:
            ClientAuthCeremonySession.find_active_by_raw_sid(auth.cookies["auth_sid"]).id,
        )
        transaction = ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
        ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
        csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        auth.post(
          "/social/#{provider}/#{sign_up ? "registration" : "session"}",
          params: { ri: "jp" },

          headers: auth_headers.merge("X-CSRF-Token" => csrf),
        )

        assert_equal 307, auth.response.status
        state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
        OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
          provider: provider, uid: subject, info: { name: "SOC provider fixture" },
          credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
          extra: { id_info: { nonce: auth.session[:social_auth_nonce] } },
        )
        assert_no_difference(
          ["Client.count", "ClientExternalIdentity.count", "ClientSignUpFlow.count",
           "ClientToken.count",],
        ) do
          auth.get("/social/#{provider}/callback", params: { state: state, ri: "jp" }, headers: auth_headers)
        end
        assert_equal [403, nil], [auth.response.status, auth.response.location]
        assert_not_predicate ceremony.reload, :authentication_evidence_recorded?
        assert_equal "pending", transaction.reload.status_name
        assert_equal [nil, nil], [auth.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],
                                  auth.cookies[AuthenticationBase::REFRESH_COOKIE_KEY],]
      end

    end

    [false, true].each do |sign_up|
      test "SOC-6: #{provider} unfinished registration is refused at #{sign_up ? "signup" : "signin"}" do
        subject = "soc6-#{SecureRandom.hex(8)}"
        actor = Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP, birthdate: "2000-01-01",
        )
        case provider
        when "google"
          ClientGoogleIdentity.create!(
            user: actor, uid: subject, provider: provider, status_id: ClientGoogleIdentityStatus::ACTIVE,
          )
        when "apple"
          ClientAppleIdentity.create!(
            user: actor, uid: subject, provider: provider, status_id: ClientAppleIdentityStatus::ACTIVE,
          )
        end
        auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        auth = open_session
        auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
        admit_social_auth!(auth, intent: sign_up ? "sign_up" : "sign_in")

        assert_equal [200, sign_up ? "/sign/up" : "/sign/in"], [auth.response.status, auth.request.path]
        binding = ClientAuthAdmissionBinding.find_by!(
          admitted_auth_ceremony_session_id:
            ClientAuthCeremonySession.find_active_by_raw_sid(auth.cookies["auth_sid"]).id,
        )
        transaction = ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
        ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
        csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        auth.post(
          "/social/#{provider}/#{sign_up ? "registration" : "session"}",
          params: { ri: "jp" },

          headers: auth_headers.merge("X-CSRF-Token" => csrf),
        )

        assert_equal 307, auth.response.status
        state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
        OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
          provider: provider, uid: subject, info: { name: "SOC provider fixture" },
          credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
          extra: { id_info: { nonce: auth.session[:social_auth_nonce] } },
        )
        assert_no_difference(
          ["Client.count", "ClientExternalIdentity.count", "ClientSignUpFlow.count",
           "ClientToken.count",],
        ) do
          auth.get("/social/#{provider}/callback", params: { state: state, ri: "jp" }, headers: auth_headers)
        end
        assert_equal [400, nil], [auth.response.status, auth.response.location]
        assert_not_predicate ceremony.reload, :authentication_evidence_recorded?
        assert_equal "pending", transaction.reload.status_name
        assert_equal [nil, nil], [auth.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],
                                  auth.cookies[AuthenticationBase::REFRESH_COOKIE_KEY],]
      end

      test "SOC-8: #{provider} abandoned #{sign_up ? "signup" : "signin"} permits fresh OIDC browser entries" do
        auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        transaction_ids = []
        binding_ids = []

        3.times do
          auth = open_session
          issuance = admit_social_auth!(auth, intent: sign_up ? "sign_up" : "sign_in")
          transaction_ids << issuance.transaction.id
          binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
          binding_ids << binding.id

          assert_equal auth_host, auth.host
          assert_equal [200, sign_up ? "/sign/up" : "/sign/in"], [auth.response.status, auth.request.path]
          assert_predicate issuance.transaction, :pending?
          assert_not_predicate(
            ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id),
            :authentication_evidence_recorded?,
          )
          assert_equal [nil, nil], [auth.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],
                                    auth.cookies[AuthenticationBase::REFRESH_COOKIE_KEY],]
        end

        assert_equal 3, transaction_ids.uniq.size
        assert_equal 3, binding_ids.uniq.size
      end
    end

    test "SOC-9: #{provider} provider refusal ends the attempt without authority" do
      auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      auth = open_session
      auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
      admit_social_auth!(auth, intent: "sign_up")

      assert_equal [200, "/sign/up"], [auth.response.status, auth.request.path]
      binding = ClientAuthAdmissionBinding.find_by!(
        admitted_auth_ceremony_session_id:
          ClientAuthCeremonySession.find_active_by_raw_sid(auth.cookies["auth_sid"]).id,
      )
      transaction = ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
      ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
      csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      auth.post(
        "/social/#{provider}/registration",
        params: { ri: "jp" },
        headers: auth_headers.merge("X-CSRF-Token" => csrf),
      )

      assert_equal 307, auth.response.status
      assert_no_difference(
        ["Client.count", "ClientExternalIdentity.count", "ClientSignUpFlow.count",
         "ClientToken.count",],
      ) do
        auth.get("/social/failure", params: { message: "access_denied", strategy: provider }, headers: auth_headers)
      end
      assert_equal [400, nil], [auth.response.status, auth.response.location]
      assert_nil auth.session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]
      assert_predicate auth.cookies["auth_sid"].to_s, :empty?
      assert_not_predicate ceremony.reload, :authentication_evidence_recorded?
      assert_equal "pending", transaction.reload.status_name
    end

    %w(confirmation birthdate).each do |step|
      next if provider == "apple" && step == "confirmation"

      test "SOC-10: #{provider} cancellation at #{step} ends its parent once and returns to RP" do
        subject = "soc10-#{SecureRandom.hex(8)}"
        auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
        jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host
        client = OidcClientRegistry.find!("core-app-jp")
        registered_redirect_uri = URI.parse(client.redirect_uris_by_realm.fetch("client").first)
        state = SecureRandom.urlsafe_base64(32)
        parameters = {
          response_type: "code",
          client_id: client.client_id,
          redirect_uri: registered_redirect_uri.to_s,
          code_challenge: OidcTestEntry::CODE_CHALLENGE,
          code_challenge_method: "S256",
          state:,
          nonce: SecureRandom.urlsafe_base64(32),
          scope: "openid profile",
          prompt: "create",
        }

        auth = open_session
        auth.host!(visa_host)
        auth.https!
        navigation = { "Sec-Fetch-Mode" => "navigate",
                       "Sec-Fetch-Dest" => "document",
                       "Sec-Fetch-Site" => "cross-site", }
        auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
        auth.get("/oauth/authorize", params: parameters, headers: navigation.merge("Sec-Fetch-Site" => "same-origin"))
        transaction = ClientOidcAuthorizationTransaction.find_by!(state:)

        12.times do
          break if auth.host == auth_host && auth.response.successful? && auth.request.path == "/sign/up"
          break unless auth.response.redirect?

          target = URI.parse(auth.response.location.to_s)
          target = URI.parse("https://#{auth.host}#{target}") if target.host.blank?
          if target.host == jump_host
            token = Rack::Utils.parse_query(target.query.to_s).fetch("rt")
            issuer = JitSecurityJwtRegistry.surface("VISA_APP")
            claims, = JWT.decode(
              token,
              JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid),
              true,
              algorithms: ["ES384"],
              verify_iss: true,
              iss: "https://#{auth.host}",
              verify_aud: true,
              aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
            )
            target = URI.parse(claims.fetch("url"))
          end

          auth.host!(target.host)
          auth.get(target.request_uri, headers: navigation)
        end

        assert_equal [auth_host, 200, "/sign/up"], [auth.host, auth.response.status, auth.request.path]
        binding = ClientAuthAdmissionBinding.find_by!(
          admitted_auth_ceremony_session_id:
            ClientAuthCeremonySession.find_active_by_raw_sid(auth.cookies["auth_sid"]).id,
        )
        ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
        registered_redirect_uri = URI.parse(transaction.redirect_uri)
        rp_host = registered_redirect_uri.host
        csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        auth.post(
          "/social/#{provider}/registration",
          params: { ri: "jp" },

          headers: auth_headers.merge("X-CSRF-Token" => csrf),
        )

        assert_equal 307, auth.response.status
        state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
        OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
          provider: provider, uid: subject, info: { name: "SOC provider fixture" },
          credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
          extra: { id_info: { nonce: auth.session[:social_auth_nonce] } },
        )
        auth.get("/social/#{provider}/callback", params: { state: state, ri: "jp" }, headers: auth_headers)

        assert_equal 302, auth.response.status
        2.times { auth.follow_redirect!(headers: navigation) }

        assert_equal 200, auth.response.status
        flow = ClientSignUpFlow.find_by!(auth_admission_binding_id: binding.id)
        csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        props = JSON.parse(auth.response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
        confirmation_action = props.fetch("action")
        cancel_action = confirmation_action
        if step == "birthdate"
          auth.patch(
            confirmation_action,
            params: { :confirm_new_social_identity => "1",
                      :checkpoint_version => flow.checkpoint_version,
                      "cf-turnstile-response" => "fixture", },
            headers: auth_headers.merge("X-CSRF-Token" => csrf),
          )

          assert_equal 302, auth.response.status
          auth.response.location
          3.times do
            break unless auth.response.redirect?

            auth.follow_redirect!(headers: navigation)
          end

          assert_equal 200, auth.response.status
          assert_equal "/sign/up/check/#{provider}/birthdate", auth.request.path
          birthdate_action = auth.request.fullpath
          csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
          cancel_action = birthdate_action
        end
        pending_client_id = flow.reload.principal_id
        assert_no_difference(["Client.count", "ClientExternalIdentity.count", "ClientToken.count"]) do
          auth.delete(
            cancel_action, params: { checkpoint_version: flow.reload.checkpoint_version },
                           headers: auth_headers.merge("X-CSRF-Token" => csrf),
          )
        end
        assert_equal(
          303, auth.response.status,
          "cancel refused at #{step}: flow_status=#{ClientSignUpFlow::STATUS_NAMES.fetch(flow.reload.status_id)} " \
          "cancelable=#{flow.sign_up_cancelable?} principal_present=#{flow.principal_id.present?} " \
          "pending_contact_type=#{flow.pending_contact_type} " \
          "pending_contact_id_present=#{flow.pending_contact_id.present?}",
        )
        rp_uri = nil
        20.times do
          if auth.response.redirect?
            target = URI.parse(auth.response.location.to_s)
            target = URI.parse("https://#{auth.host}#{target}") if target.host.blank?
            if target.host == jump_host
              token = Rack::Utils.parse_query(target.query.to_s).fetch("rt")
              issuer_id = (auth.host == auth_host) ? "AUTH_APP" : "VISA_APP"
              issuer = JitSecurityJwtRegistry.surface(issuer_id)
              claims, = JWT.decode(
                token,
                JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid),
                true,
                algorithms: ["ES384"],
                verify_iss: true,
                iss: "https://#{auth.host}",
                verify_aud: true,
                aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
              )
              target = URI.parse(claims.fetch("url"))
            end
            if target.host == rp_host
              rp_uri = target
              break
            end

            auth.host!(target.host)
            auth.get(target.request_uri, headers: navigation)
            next
          end

          form = auth.response.parsed_body.at_css("form#visa-authorization-continuation-form")
          break unless form

          target = URI.join("https://#{auth.host}", form["action"])
          fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
          auth.host!(target.host)
          auth.post(
            target.request_uri,
            params: fields,
            headers: { "Origin" => "https://#{target.host}", "Sec-Fetch-Site" => "same-origin" },
          )
        end

        assert_equal [rp_uri.host, rp_uri.path], [rp_host, URI.parse(transaction.redirect_uri).path]
        assert_equal transaction.state, Rack::Utils.parse_nested_query(rp_uri.query).fetch("state")
        assert_equal "access_denied", Rack::Utils.parse_nested_query(rp_uri.query).fetch("error")
        assert_predicate transaction.reload, :canceled?
        assert_predicate ceremony.reload, :cancelled?
        assert_not_predicate flow.reload, :completed?
        if pending_client_id
          pending_client = Client.find(pending_client_id)

          assert_predicate pending_client.discard_at, :present?
          assert_operator pending_client.purge_eligible_at, :>, Time.current
        end

        assert_equal 0, ClientExternalIdentity.where(provider: provider, subject: subject).count
        cancellation_query = Rack::Utils.parse_nested_query(rp_uri.query)

        assert_empty cancellation_query.keys & %w(code access_token id_token)
        terminal_state = [transaction.attributes, ceremony.attributes, flow.attributes]
        auth.delete(
          cancel_action, params: { checkpoint_version: flow.checkpoint_version },
                         headers: auth_headers.merge("X-CSRF-Token" => csrf),
        )

        assert_operator auth.response.status, :>=, 400
        assert_operator auth.response.status, :<, 500
        assert_equal terminal_state, [transaction.reload.attributes, ceremony.reload.attributes, flow.reload.attributes]
      end
    end

    %w(first confirmation).each do |earlier|
      test "SOC-11: #{provider} GET of #{earlier} page after advancing preserves all state" do
        sign_up = true
        subject = "soc11-#{SecureRandom.hex(8)}"
        auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        auth = open_session
        navigation = { "Sec-Fetch-Mode" => "navigate",
                       "Sec-Fetch-Dest" => "document",
                       "Sec-Fetch-Site" => "cross-site", }
        auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
        admit_social_auth!(auth, intent: "sign_up")

        assert_equal [200, "/sign/up"], [auth.response.status, auth.request.path]
        binding = ClientAuthAdmissionBinding.find_by!(
          admitted_auth_ceremony_session_id:
            ClientAuthCeremonySession.find_active_by_raw_sid(auth.cookies["auth_sid"]).id,
        )
        transaction = ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
        ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
        csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        auth.post(
          "/social/#{provider}/#{sign_up ? "registration" : "session"}",
          params: { ri: "jp" },

          headers: auth_headers.merge("X-CSRF-Token" => csrf),
        )

        assert_equal 307, auth.response.status
        state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
        OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
          provider: provider, uid: subject, info: { name: "SOC provider fixture" },
          credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
          extra: { id_info: { nonce: auth.session[:social_auth_nonce] } },
        )
        auth.get("/social/#{provider}/callback", params: { state: state, ri: "jp" }, headers: auth_headers)

        assert_equal 302, auth.response.status
        2.times { auth.follow_redirect!(headers: navigation) }

        assert_equal 200, auth.response.status
        flow = ClientSignUpFlow.find_by!(auth_admission_binding_id: binding.id)
        props = JSON.parse(auth.response.parsed_body.at_css("script[data-page='app']").text).fetch("props")
        confirmation_action = props.fetch("action")
        if earlier == "confirmation"
          auth.patch(
            confirmation_action,
            params: { :confirm_new_social_identity => "1",
                      :checkpoint_version => flow.checkpoint_version,
                      "cf-turnstile-response" => "fixture", },
            headers: auth_headers.merge("X-CSRF-Token" => csrf),
          )

          assert_equal 302, auth.response.status
          auth.response.location
          3.times do
            break unless auth.response.redirect?

            auth.follow_redirect!(headers: navigation)
          end

          assert_equal 200, auth.response.status
          assert_equal "/sign/up/check/#{provider}/birthdate", auth.request.path
          auth.request.fullpath
          auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        end
        snapshot = [flow.reload.attributes, ceremony.reload.attributes, transaction.reload.attributes]
        assert_no_difference(["Client.count", "ClientExternalIdentity.count", "ClientToken.count"]) do
          auth.get(
            (earlier == "first") ? "/sign/up?ri=jp" : confirmation_action,
            params: { ri: "jp" }, headers: navigation,
          )
        end
        redirect_path = auth.response.location && URI.parse(auth.response.location).path

        assert_equal 409, auth.response.status, "unexpected refusal redirect to #{redirect_path}"
        cookie_names =
          Array(auth.response.headers["Set-Cookie"]).flat_map { |header|
            header.split(
              "
      ",
            )
          }.map { |header| header.split("=", 2).first }

        assert_empty cookie_names & ["auth_sid", Rails.application.config.session_options.fetch(:key),
                                     AuthenticationBase::ACCESS_COOKIE_KEY, AuthenticationBase::REFRESH_COOKIE_KEY,]
        assert_equal snapshot, [flow.reload.attributes, ceremony.reload.attributes, transaction.reload.attributes]
      end
    end

    [false, true].each do |sign_up|
      test "SOC-12: #{provider} #{sign_up ? "signup" : "signin"} replay creates no second account or session" do
        subject = "soc12-#{SecureRandom.hex(8)}"
        unless sign_up
          actor = Client.create!(
            security_mode_id: SecurityModeConfigurable::NORMAL,
            status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01",
          )
          case provider
          when "google"
            ClientGoogleIdentity.create!(
              user: actor, uid: subject, provider: provider, status_id: ClientGoogleIdentityStatus::ACTIVE,
            )
          when "apple"
            ClientAppleIdentity.create!(
              user: actor, uid: subject, provider: provider, status_id: ClientAppleIdentityStatus::ACTIVE,
            )
          end
        end
        auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        auth = open_session
        auth_headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }
        admit_social_auth!(auth, intent: sign_up ? "sign_up" : "sign_in")

        assert_equal [200, sign_up ? "/sign/up" : "/sign/in"], [auth.response.status, auth.request.path]
        binding = ClientAuthAdmissionBinding.find_by!(
          admitted_auth_ceremony_session_id:
            ClientAuthCeremonySession.find_active_by_raw_sid(auth.cookies["auth_sid"]).id,
        )
        transaction = ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id)
        ceremony = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)
        csrf = auth.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
        auth.post(
          "/social/#{provider}/#{sign_up ? "registration" : "session"}",
          params: { ri: "jp" },

          headers: auth_headers.merge("X-CSRF-Token" => csrf),
        )

        assert_equal 307, auth.response.status
        state = auth.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
        OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
          provider: provider, uid: subject, info: { name: "SOC provider fixture" },
          credentials: { token: "provider-fixture", expires_at: 1.hour.from_now.to_i },
          extra: { id_info: { nonce: auth.session[:social_auth_nonce] } },
        )
        auth.get("/social/#{provider}/callback", params: { state: state, ri: "jp" }, headers: auth_headers)

        assert_equal(sign_up ? 302 : 303, auth.response.status)
        snapshot = [ceremony.reload.attributes, transaction.reload.attributes]
        assert_no_difference(
          ["Client.count", "ClientExternalIdentity.count", "ClientSignUpFlow.count",
           "ClientToken.count",],
        ) do
          auth.get("/social/#{provider}/callback", params: { state: state, ri: "jp" }, headers: auth_headers)
        end
        assert_equal 403, auth.response.status
        assert_equal snapshot, [ceremony.reload.attributes, transaction.reload.attributes]
        assert_equal [nil, nil], [auth.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],
                                  auth.cookies[AuthenticationBase::REFRESH_COOKIE_KEY],]
      end
    end

    test "SOC-13: #{provider} registered signup refusal preserves a fresh OIDC sign-in" do
      subject = "soc13-#{SecureRandom.hex(8)}"
      actor = Client.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL,
        status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01",
      )
      case provider
      when "google"
        ClientGoogleIdentity.create!(
          user: actor, uid: subject, provider:, status_id: ClientGoogleIdentityStatus::ACTIVE,
        )
      when "apple"
        ClientAppleIdentity.create!(
          user: actor, uid: subject, provider:, status_id: ClientAppleIdentityStatus::ACTIVE,
        )
      end

      auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      base_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
      client = OidcClientRegistry.find!("core-app-jp")
      expected_redirect_uri = client.redirect_uris_by_realm.fetch("client").first
      headers = { "Origin" => "https://#{auth_host}", "Sec-Fetch-Site" => "same-origin" }

      sign_up = open_session
      sign_up_issuance = admit_social_auth!(sign_up, intent: "sign_in")
      admit_browser_to_sign_up!(sign_up)
      sign_up_binding = social_admission_binding_for(sign_up)
      sign_up_transaction = ClientOidcAuthorizationTransaction.find(sign_up_binding.authorization_transaction_id)
      sign_up_ceremony = ClientAuthCeremonySession.find(sign_up_binding.admitted_auth_ceremony_session_id)
      csrf = sign_up.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]
      sign_up.post(
        "/social/#{provider}/registration", params: { ri: "jp" },
                                            headers: headers.merge("X-CSRF-Token" => csrf),
      )

      assert_equal 307, sign_up.response.status
      state = sign_up.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
      set_social_provider_fixture(sign_up, provider, subject)
      assert_no_difference(["Client.count", "ClientExternalIdentity.count", "ClientToken.count"]) do
        sign_up.get("/social/#{provider}/callback", params: { state:, ri: "jp" }, headers: headers)
      end

      assert_equal 400, sign_up.response.status
      assert_nil sign_up.response.location
      assert_empty sign_up.response.parsed_body.css("main a")
      assert_not_includes sign_up.response.body, base_host
      assert_not_predicate sign_up_ceremony.reload, :authentication_evidence_recorded?
      assert_equal "pending", sign_up_transaction.reload.status_name
      assert_equal [nil, nil], [sign_up.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],
                                sign_up.cookies[AuthenticationBase::REFRESH_COOKIE_KEY],]

      fresh = open_session
      fresh_issuance = admit_social_auth!(fresh, intent: "sign_in")
      fresh_binding = social_admission_binding_for(fresh)
      fresh_transaction = ClientOidcAuthorizationTransaction.find(fresh_binding.authorization_transaction_id)
      fresh_ceremony = ClientAuthCeremonySession.find(fresh_binding.admitted_auth_ceremony_session_id)
      fresh_csrf = fresh.response.parsed_body.at_css('meta[name="csrf-token"]')["content"]

      assert_not_equal sign_up_issuance.transaction.id, fresh_issuance.transaction.id
      assert_not_equal sign_up_binding.id, fresh_binding.id
      assert_equal expected_redirect_uri, fresh_transaction.redirect_uri
      fresh.post(
        "/social/#{provider}/session", params: { ri: "jp" },
                                       headers: headers.merge("X-CSRF-Token" => fresh_csrf),
      )

      assert_equal 307, fresh.response.status
      state = fresh.session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
      set_social_provider_fixture(fresh, provider, subject)
      assert_no_difference(["Client.count", "ClientExternalIdentity.count", "ClientToken.count"]) do
        fresh.get("/social/#{provider}/callback", params: { state:, ri: "jp" }, headers: headers)
      end

      assert_equal 303, fresh.response.status
      handoff = URI.parse(fresh.response.location)

      assert_equal auth_host, handoff.host
      assert_equal "/sign/in/check", handoff.path
      assert_predicate fresh_ceremony.reload, :authentication_evidence_recorded?
      assert_equal provider, fresh_ceremony.authentication_method
      assert_equal "pending", fresh_transaction.reload.status_name
      assert_equal [nil, nil], [fresh.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],
                                fresh.cookies[AuthenticationBase::REFRESH_COOKIE_KEY],]
      snapshot = [fresh_binding.reload.attributes, fresh_transaction.reload.attributes,
                  fresh_ceremony.reload.attributes,]
      fresh.get("/social/#{provider}/callback", params: { state:, ri: "jp" }, headers: headers)

      assert_equal 403, fresh.response.status
      assert_equal snapshot, [fresh_binding.reload.attributes, fresh_transaction.reload.attributes,
                              fresh_ceremony.reload.attributes,]

      fresh.get(
        "/sign/oidc/handoff", params: { ri: "jp" },
                              headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" },
      )

      assert_equal 303, fresh.response.status
      result_location = URI.parse(jump_rt_url_from_location_for_test(fresh.response.location))

      assert_equal visa_host, result_location.host
      assert_equal "/oidc/result", result_location.path
    end
  end
end
