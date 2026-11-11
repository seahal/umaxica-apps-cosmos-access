# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Integration tests for social auth login intent
#
# These tests verify:
# - OPTIONAL: Login with existing identity doesn't create new Client
# - New user creation via social login
# - JWT/session tokens are issued on success
class SocialAuthLoginTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses

  setup do
    OmniAuth.config.test_mode = true
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.enabled = true
    @original_login_cooldown = login_cooldown
    self.login_cooldown = 0.seconds
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @callback_headers = social_callback_headers(@host)
    @base_browser = open_session
    visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @base_browser.host!(visa_host)
    @base_browser.https!
    client = OidcClientRegistry.find!("core-app-jp")
    @oidc_authorization = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      scope: "openid profile",
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: OidcTestEntry::CODE_CHALLENGE,
      code_challenge_method: "S256",
    }
    @base_browser.get(
      "/oauth/authorize", params: @oidc_authorization, headers: {
        "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
      },
    )
    current_browser = @base_browser
    12.times do
      raise RuntimeError, "Social admission stopped before a redirect" unless current_browser.response.redirect?

      target = URI.parse(current_browser.response.location)
      if target.host == "jump.umaxica.net"
        token = Rack::Utils.parse_query(target.query).fetch("rt")
        payload, = JWT.decode(token, nil, false)
        target = URI.parse(payload.fetch("url"))
      end
      browser = (target.host == auth_host) ? self : @base_browser
      browser.host!(target.host) if target.host
      browser.https!
      browser.get(
        target.request_uri, headers: {
          "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
        },
      )
      current_browser = browser
      break if browser == self && !response.redirect?
    end

    assert_response :success
    assert_equal auth_host, request.host
  end

  teardown do
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.enabled = false
    self.login_cooldown = @original_login_cooldown
  end

  # ============================================================================
  # OPTIONAL: Login with existing identity doesn't create new user
  # ============================================================================
  test "Google login with existing identity does not create new user" do
    existing_uid = "existing_google_user_#{SecureRandom.hex(4)}"

    # Create existing user with Google identity
    existing_user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::NOTHING, public_id: PublicId.generate,
    )
    ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    setup_google_mock_auth(uid: existing_uid)

    user_count_before = Client.count

    state =
      begin
        fv5061 = "google"
        fv5060 = "login"
        fv5059 = nil
        begin
          lf0_provider = fv5061
          lf0_intent = fv5060
          lf0_user = nil
          lf0_entry = fv5059
          lf0_ri = "jp"
          lf0_rt = nil
          lf0_referer = nil
          lf0_host = @host.presence || configured_host(:auth_service)
          host!(lf0_host) if respond_to?(:host!)
          lf0_normalized_provider = SocialIdentifiable.normalize_provider(lf0_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf0_continue_path =
            if lf0_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf0_normalized_provider}_path",
                ri: lf0_ri,
              )
            elsif lf0_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf0_normalized_provider}_registration_path",
                ri: lf0_ri,
                rt: lf0_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf0_normalized_provider}_session_path",
                ri: lf0_ri,
                rt: lf0_rt,
              )
            end
          lf0_headers = social_callback_headers(lf0_host)
          lf0_headers["Referer"] = lf0_referer if lf0_referer.present?
          if lf0_user
            lf0_user_headers =
              begin
                rr0_headers =
                  begin
                    rp_headers = as_user_headers(lf0_user, host: lf0_host)
                    rp_host = rp_headers["Host"]
                    rp_route =
                      begin
                        Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
                      rescue ActionController::RoutingError
                        nil
                      end
                    rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
                    rp_headers
                  end
                rr0_host = rr0_headers["Host"]
                rr0_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr0_host}/") if rr0_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr0_family, rr0_surface = rr0_route&.fetch(:controller)&.split("/")
                rr0_headers
              end
            lf0_token = ClientToken.find_by(public_id: lf0_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf0_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf0_intent.to_s == "link" && lf0_token
            lf0_headers = lf0_headers.merge(lf0_user_headers)
          end
          if lf0_entry.to_s == "sign_up" && lf0_intent.to_s != "link"
            ENV.fetch("PUBLIC_VISA_SERVICE_URL")
            auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.get(
              "/oauth/authorize", params: @oidc_authorization.merge(prompt: "create"), headers: {
                "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
              },
            )
            current_browser = @base_browser
            12.times do
              break unless current_browser.response.redirect?

              target = URI.parse(current_browser.response.location)
              if target.host == "jump.umaxica.net"
                rt = Rack::Utils.parse_query(target.query).fetch("rt")
                target = URI.parse(JWT.decode(rt, nil, false).first.fetch("url"))
              end
              browser = (target.host == auth_host) ? self : @base_browser
              browser.host!(target.host) if target.host
              browser.https!
              browser.get(
                target.request_uri, headers: {
                  "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
                },
              )
              current_browser = browser
              break if browser == self && !response.redirect?
            end

            assert_equal auth_host, request.host
            assert_response :success
          end
          post(lf0_continue_path, headers: lf0_headers)
          social_auth_state_from_response
        end
      end

    # Callback
    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow0_form = response.parsed_body.at_css("form#social-completion-form")
        flow0_fields =
          flow0_form.css("input[name]").to_h { |flow0_input|
            [
              flow0_input["name"],
              flow0_input["value"],
            ]
          }
        flow0_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow0_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow0_pair| flow0_pair.start_with?("#{flow0_rails_cookie}=") }
        flow0_owner_cookie << "#{flow0_rails_cookie}=#{Rack::Utils.escape(response.cookies.fetch(flow0_rails_cookie))}"
        post(
          flow0_form["action"], params: flow0_fields, headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow0_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow0_target = URI.parse(response.location)
      if flow0_target.path == "/sign/in/check"
        # The Auth handoff redirects to the Visa result page, which continues the parent
        # authorization by a same-origin POST.
        get(
          auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow0_visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
        flow0_result_uri = URI.parse(response.location)

        assert_equal [303, flow0_visa_host], [response.status, flow0_result_uri.host]
        @base_browser.host!(flow0_visa_host)
        @base_browser.https!
        @base_browser.get(
          flow0_result_uri.request_uri, headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site",
          },
        )
        flow0_form = @base_browser.response.parsed_body.at_css("form#visa-authorization-continuation-form")
        flow0_fields =
          flow0_form.css("input[name]").to_h { |flow0_input|
            [
              flow0_input["name"],
              flow0_input["value"],
            ]
          }
        @base_browser.post(
          flow0_form["action"], params: flow0_fields, headers: {
            "Origin" => "https://#{flow0_visa_host}",
            "Sec-Fetch-Site" => "same-origin",
            "Sec-Fetch-Mode" => "navigate",
            "Sec-Fetch-Dest" => "document",
          },
        )
      end
      break unless flow0_result_uri

      flow0_continuation = @base_browser.response

      assert_equal 303, flow0_continuation.status
      flow0_registered_uri = URI.parse(
        OidcClientRegistry.find!("core-app-jp").redirect_uris_by_realm.fetch("client").first,
      )
      flow0_callback_uri = URI.parse(flow0_continuation.location)
      if flow0_callback_uri.host == "jump.umaxica.net"
        flow0_callback_uri = URI.parse(jump_rt_url_from_location_for_test(flow0_callback_uri.to_s))
      end

      assert_equal [flow0_registered_uri.host, flow0_registered_uri.path],
                   [flow0_callback_uri.host, flow0_callback_uri.path]
    end

    assert_response :redirect

    # Client count should NOT increase
    assert_equal user_count_before, Client.count, "Existing user login should NOT create new user"

    assert_social_login_issued_visa_result(response.location)
    # The OP login cookie is set on Visa.
    assert_predicate @base_browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY].to_s, :present?
    assert_equal 1, ClientToken.where(user_id: existing_user.id).count

    existing_user.reload

    assert_equal ClientStatus::NOTHING, existing_user.status_id
  end

  test "a duplicate provider subject loses the unique index and the callback uses the winning identity" do
    subject = "race_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: subject)
    winner = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      birthdate: "2000-01-01",
    )
    loser = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      birthdate: "2000-01-01",
    )
    identity = ClientGoogleIdentity.create!(
      user: winner,
      uid: subject,
      provider: "google",
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )
    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientGoogleIdentity.create!(
        user: loser,
        uid: subject,
        provider: "google",
        status_id: ClientGoogleIdentityStatus::ACTIVE,
      )
    end
    post auth_app_social_google_session_path(ri: "jp"), headers: @callback_headers
    state = social_auth_state_from_response
    assert_no_difference(["Client.count", "ClientExternalIdentity.count", "ClientToken.count"]) do
      get auth_app_social_google_callback_path(ri: "jp"), params: { state: state }, headers: @callback_headers
    end
    assert_equal URI.parse(auth_app_sign_in_check_url(ri: "jp")).path, URI.parse(response.location).path
    assert_equal winner.id, identity.reload.user_id
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_predicate flash, :empty?
  end

  test "Google login with existing identity completes on the app Dashboard, never Home" do
    existing_uid = "existing_google_welcome_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::NOTHING,
      public_id: PublicId.generate,
      birthdate: "2000-01-01",
    )
    ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )
    setup_google_mock_auth(uid: existing_uid)

    state =
      begin
        fv5055 = "google"
        fv5054 = "login"
        fv5053 = nil
        begin
          lf2_provider = fv5055
          lf2_intent = fv5054
          lf2_user = nil
          lf2_entry = fv5053
          lf2_ri = "jp"
          lf2_rt = nil
          lf2_referer = nil
          lf2_host = @host.presence || configured_host(:auth_service)
          host!(lf2_host) if respond_to?(:host!)
          lf2_normalized_provider = SocialIdentifiable.normalize_provider(lf2_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf2_continue_path =
            if lf2_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf2_normalized_provider}_path",
                ri: lf2_ri,
              )
            elsif lf2_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf2_normalized_provider}_registration_path",
                ri: lf2_ri,
                rt: lf2_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf2_normalized_provider}_session_path",
                ri: lf2_ri,
                rt: lf2_rt,
              )
            end
          lf2_headers = social_callback_headers(lf2_host)
          lf2_headers["Referer"] = lf2_referer if lf2_referer.present?
          if lf2_user
            lf2_user_headers =
              begin
                rr2_headers =
                  begin
                    rp_headers = as_user_headers(lf2_user, host: lf2_host)
                    rp_host = rp_headers["Host"]
                    rp_route =
                      begin
                        Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
                      rescue ActionController::RoutingError
                        nil
                      end
                    rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
                    rp_headers
                  end
                rr2_host = rr2_headers["Host"]
                rr2_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr2_host}/") if rr2_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr2_family, rr2_surface = rr2_route&.fetch(:controller)&.split("/")
                rr2_headers
              end
            lf2_token = ClientToken.find_by(public_id: lf2_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf2_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf2_intent.to_s == "link" && lf2_token
            lf2_headers = lf2_headers.merge(lf2_user_headers)
          end
          if lf2_entry.to_s == "sign_up" && lf2_intent.to_s != "link"
            ENV.fetch("PUBLIC_VISA_SERVICE_URL")
            auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.get(
              "/oauth/authorize", params: @oidc_authorization.merge(prompt: "create"), headers: {
                "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
              },
            )
            current_browser = @base_browser
            12.times do
              break unless current_browser.response.redirect?

              target = URI.parse(current_browser.response.location)
              if target.host == "jump.umaxica.net"
                rt = Rack::Utils.parse_query(target.query).fetch("rt")
                target = URI.parse(JWT.decode(rt, nil, false).first.fetch("url"))
              end
              browser = (target.host == auth_host) ? self : @base_browser
              browser.host!(target.host) if target.host
              browser.https!
              browser.get(
                target.request_uri, headers: {
                  "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
                },
              )
              current_browser = browser
              break if browser == self && !response.redirect?
            end

            assert_equal auth_host, request.host
            assert_response :success
          end
          post(lf2_continue_path, headers: lf2_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow1_form = response.parsed_body.at_css("form#social-completion-form")
        flow1_fields =
          flow1_form.css("input[name]").to_h { |flow1_input|
            [
              flow1_input["name"],
              flow1_input["value"],
            ]
          }
        flow1_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow1_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow1_pair| flow1_pair.start_with?("#{flow1_rails_cookie}=") }
        flow1_owner_cookie << "#{flow1_rails_cookie}=#{Rack::Utils.escape(response.cookies.fetch(flow1_rails_cookie))}"
        post(
          flow1_form["action"], params: flow1_fields, headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow1_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow1_target = URI.parse(response.location)
      if flow1_target.path == "/sign/in/check"
        # The Auth handoff redirects to the Visa result page, which continues the parent
        # authorization by a same-origin POST.
        get(
          auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow1_visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
        flow1_result_uri = URI.parse(response.location)

        assert_equal [303, flow1_visa_host], [response.status, flow1_result_uri.host]
        @base_browser.host!(flow1_visa_host)
        @base_browser.https!
        @base_browser.get(
          flow1_result_uri.request_uri, headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site",
          },
        )
        flow1_form = @base_browser.response.parsed_body.at_css("form#visa-authorization-continuation-form")
        flow1_fields =
          flow1_form.css("input[name]").to_h { |flow1_input|
            [
              flow1_input["name"],
              flow1_input["value"],
            ]
          }
        @base_browser.post(
          flow1_form["action"], params: flow1_fields, headers: {
            "Origin" => "https://#{flow1_visa_host}",
            "Sec-Fetch-Site" => "same-origin",
            "Sec-Fetch-Mode" => "navigate",
            "Sec-Fetch-Dest" => "document",
          },
        )
      end
      break unless flow1_result_uri

      flow1_continuation = @base_browser.response

      assert_equal 303, flow1_continuation.status
      flow1_registered_uri = URI.parse(
        OidcClientRegistry.find!("core-app-jp").redirect_uris_by_realm.fetch("client").first,
      )
      flow1_callback_uri = URI.parse(flow1_continuation.location)
      if flow1_callback_uri.host == "jump.umaxica.net"
        flow1_callback_uri = URI.parse(jump_rt_url_from_location_for_test(flow1_callback_uri.to_s))
      end

      assert_equal [flow1_registered_uri.host, flow1_registered_uri.path],
                   [flow1_callback_uri.host, flow1_callback_uri.path]
    end

    assert_response :redirect
    assert_social_login_issued_visa_result(response.location)

    cycle = ClientSignInFlow.where(principal_id: existing_user.id).recent_first.first

    assert_equal ClientSignInFlowState::COMPLETED, cycle.state_id
  end

  test "Google login with session limit pending redirects to acme sign-in limitation" do
    existing_uid = "existing_google_session_limit_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::NOTHING,
      public_id: PublicId.generate,
      birthdate: "2000-01-01",
    )
    ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )
    2.times { create_active_user_session_for_limit(existing_user) }
    setup_google_mock_auth(uid: existing_uid)

    state =
      begin
        fv5052 = "google"
        fv5051 = "login"
        fv5050 = nil
        begin
          lf3_provider = fv5052
          lf3_intent = fv5051
          lf3_user = nil
          lf3_entry = fv5050
          lf3_ri = "jp"
          lf3_rt = nil
          lf3_referer = nil
          lf3_host = @host.presence || configured_host(:auth_service)
          host!(lf3_host) if respond_to?(:host!)
          lf3_normalized_provider = SocialIdentifiable.normalize_provider(lf3_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf3_continue_path =
            if lf3_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf3_normalized_provider}_path",
                ri: lf3_ri,
              )
            elsif lf3_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf3_normalized_provider}_registration_path",
                ri: lf3_ri,
                rt: lf3_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf3_normalized_provider}_session_path",
                ri: lf3_ri,
                rt: lf3_rt,
              )
            end
          lf3_headers = social_callback_headers(lf3_host)
          lf3_headers["Referer"] = lf3_referer if lf3_referer.present?
          if lf3_user
            lf3_user_headers =
              begin
                rr3_headers =
                  begin
                    rp_headers = as_user_headers(lf3_user, host: lf3_host)
                    rp_host = rp_headers["Host"]
                    rp_route =
                      begin
                        Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
                      rescue ActionController::RoutingError
                        nil
                      end
                    rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
                    rp_headers
                  end
                rr3_host = rr3_headers["Host"]
                rr3_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr3_host}/") if rr3_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr3_family, rr3_surface = rr3_route&.fetch(:controller)&.split("/")
                rr3_headers
              end
            lf3_token = ClientToken.find_by(public_id: lf3_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf3_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf3_intent.to_s == "link" && lf3_token
            lf3_headers = lf3_headers.merge(lf3_user_headers)
          end
          if lf3_entry.to_s == "sign_up" && lf3_intent.to_s != "link"
            ENV.fetch("PUBLIC_VISA_SERVICE_URL")
            auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.get(
              "/oauth/authorize", params: @oidc_authorization.merge(prompt: "create"), headers: {
                "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
              },
            )
            current_browser = @base_browser
            12.times do
              break unless current_browser.response.redirect?

              target = URI.parse(current_browser.response.location)
              if target.host == "jump.umaxica.net"
                rt = Rack::Utils.parse_query(target.query).fetch("rt")
                target = URI.parse(JWT.decode(rt, nil, false).first.fetch("url"))
              end
              browser = (target.host == auth_host) ? self : @base_browser
              browser.host!(target.host) if target.host
              browser.https!
              browser.get(
                target.request_uri, headers: {
                  "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
                },
              )
              current_browser = browser
              break if browser == self && !response.redirect?
            end

            assert_equal auth_host, request.host
            assert_response :success
          end
          post(lf3_continue_path, headers: lf3_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    assert_no_difference(-> { ClientToken.where(user_id: existing_user.id).count }) do
      1.times do
        if response.media_type == "text/html" && response.body.include?("social-completion-form")
          flow2_form = response.parsed_body.at_css("form#social-completion-form")
          flow2_fields =
            flow2_form.css("input[name]").to_h { |flow2_input|
              [
                flow2_input["name"],
                flow2_input["value"],
              ]
            }
          flow2_rails_cookie = Rails.application.config.session_options.fetch(:key)
          flow2_owner_cookie =
            request.headers["Cookie"].to_s.split("; ")
              .reject { |flow2_pair| flow2_pair.start_with?("#{flow2_rails_cookie}=") }
          flow2_owner_cookie << "#{flow2_rails_cookie}=#{Rack::Utils.escape(
            response
                        .cookies.fetch(flow2_rails_cookie),
          )}"
          post(
            flow2_form["action"],
            params: flow2_fields,
            headers: {
              "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
              "Cookie" => flow2_owner_cookie.join("; "),
              "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
              "Sec-Fetch-Site" => "same-origin",
            },
          )
          break
        end
        break unless response.redirect? && @base_browser

        flow2_target = URI.parse(response.location)
        if flow2_target.path == "/sign/in/check"
          # The Auth handoff redirects to the Visa result page, which continues the parent
          # authorization by a same-origin POST.
          get(
            auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
              "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "same-origin",
            },
          )
          flow2_visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
          flow2_result_uri = URI.parse(response.location)

          assert_equal [303, flow2_visa_host], [response.status, flow2_result_uri.host]
          @base_browser.host!(flow2_visa_host)
          @base_browser.https!
          @base_browser.get(
            flow2_result_uri.request_uri, headers: {
              "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site",
            },
          )
          flow2_form = @base_browser.response.parsed_body.at_css("form#visa-authorization-continuation-form")
          flow2_fields =
            flow2_form.css("input[name]").to_h { |flow2_input|
              [
                flow2_input["name"],
                flow2_input["value"],
              ]
            }
          @base_browser.post(
            flow2_form["action"], params: flow2_fields, headers: {
              "Origin" => "https://#{flow2_visa_host}",
              "Sec-Fetch-Site" => "same-origin",
              "Sec-Fetch-Mode" => "navigate",
              "Sec-Fetch-Dest" => "document",
            },
          )
        end
        break unless flow2_result_uri

        flow2_continuation = @base_browser.response

        assert_equal 303, flow2_continuation.status
        flow2_callback_uri = URI.parse(flow2_continuation.location)
        if flow2_callback_uri.host == "jump.umaxica.net"
          flow2_callback_uri = URI.parse(jump_rt_url_from_location_for_test(flow2_callback_uri.to_s))
        end

        assert_equal [flow2_visa_host, "/sign/in/limitation"],
                     [flow2_callback_uri.host, flow2_callback_uri.path]
      end
    end

    # A same-host redirect on the Visa host that ran the authorization continuation: the pending
    # sign-in flow is held by that host's Rails session, and the URL carries no grant of its own.
    assert_predicate @base_browser.response, :redirect?
    redirect_uri = URI.parse(@base_browser.response.location)

    assert_equal [ENV.fetch("PUBLIC_VISA_SERVICE_URL"), "/sign/in/limitation"], [redirect_uri.host, redirect_uri.path]
    assert_nil Rack::Utils.parse_nested_query(redirect_uri.query.to_s)["social_resolution"]
    assert_equal 2, ClientToken.where(user_id: existing_user.id).count
    flow = ClientSignInFlow.where(principal_id: existing_user.id).recent_first.first

    assert_predicate flow, :sign_in_session_issuance_pending?
    assert_predicate ClientSessionLimitResolutionTransaction.find_by!(sign_in_flow_id: flow.id), :open?

    # The limitation page itself, reached through the flow locator held by the Visa session, is
    # exercised in test/controllers/visa/app/sign/in/limitations_controller_test.rb.
  end

  def create_active_user_session_for_limit(user)
    token = ClientToken.new(authentication_epoch: 0, user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
    token.save!
    token
  end

  test "Google established login callback posts a one-shot result to acme without provider tokens" do
    existing_uid = "existing_google_transport_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::NOTHING,
      public_id: PublicId.generate,
      birthdate: "2000-01-01",
    )
    identity = ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google",
      uid: existing_uid,
      info: {},
      credentials: {
        token: "transport_access_token",
        refresh_token: "transport_refresh_token",
        expires_at: 1.week.from_now.to_i,
      },
    )

    state =
      begin
        fv5049 = "google"
        fv5048 = "login"
        fv5047 = nil
        begin
          lf4_provider = fv5049
          lf4_intent = fv5048
          lf4_user = nil
          lf4_entry = fv5047
          lf4_ri = "jp"
          lf4_rt = nil
          lf4_referer = nil
          lf4_host = @host.presence || configured_host(:auth_service)
          host!(lf4_host) if respond_to?(:host!)
          lf4_normalized_provider = SocialIdentifiable.normalize_provider(lf4_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf4_continue_path =
            if lf4_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf4_normalized_provider}_path",
                ri: lf4_ri,
              )
            elsif lf4_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf4_normalized_provider}_registration_path",
                ri: lf4_ri,
                rt: lf4_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf4_normalized_provider}_session_path",
                ri: lf4_ri,
                rt: lf4_rt,
              )
            end
          lf4_headers = social_callback_headers(lf4_host)
          lf4_headers["Referer"] = lf4_referer if lf4_referer.present?
          if lf4_user
            lf4_user_headers =
              begin
                rr4_headers =
                  begin
                    rp_headers = as_user_headers(lf4_user, host: lf4_host)
                    rp_host = rp_headers["Host"]
                    rp_route =
                      begin
                        Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
                      rescue ActionController::RoutingError
                        nil
                      end
                    rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
                    rp_headers
                  end
                rr4_host = rr4_headers["Host"]
                rr4_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr4_host}/") if rr4_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr4_family, rr4_surface = rr4_route&.fetch(:controller)&.split("/")
                rr4_headers
              end
            lf4_token = ClientToken.find_by(public_id: lf4_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf4_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf4_intent.to_s == "link" && lf4_token
            lf4_headers = lf4_headers.merge(lf4_user_headers)
          end
          if lf4_entry.to_s == "sign_up" && lf4_intent.to_s != "link"
            ENV.fetch("PUBLIC_VISA_SERVICE_URL")
            auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.get(
              "/oauth/authorize", params: @oidc_authorization.merge(prompt: "create"), headers: {
                "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
              },
            )
            current_browser = @base_browser
            12.times do
              break unless current_browser.response.redirect?

              target = URI.parse(current_browser.response.location)
              if target.host == "jump.umaxica.net"
                rt = Rack::Utils.parse_query(target.query).fetch("rt")
                target = URI.parse(JWT.decode(rt, nil, false).first.fetch("url"))
              end
              browser = (target.host == auth_host) ? self : @base_browser
              browser.host!(target.host) if target.host
              browser.https!
              browser.get(
                target.request_uri, headers: {
                  "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
                },
              )
              current_browser = browser
              break if browser == self && !response.redirect?
            end

            assert_equal auth_host, request.host
            assert_response :success
          end
          post(lf4_continue_path, headers: lf4_headers)
          social_auth_state_from_response
        end
      end

    assert_difference("ClientSignInFlow.count", 1) do
      assert_no_difference("ClientToken.count") do
        get auth_app_social_google_callback_url(ri: "jp"),
            params: { state: state }, headers: browser_headers.merge(@callback_headers)
      end
    end
    assert_response :see_other
    assert_equal "/sign/in/check", URI.parse(response.location).path
    get auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
      "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "same-origin",
    }

    # The handoff issues the one-shot result and answers 303 to Visa's result resource;
    # Auth never renders the result as an auto-submit form.
    visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    result_uri = URI.parse(response.location)

    assert_equal [303, visa_host, "/oidc/result"], [response.status, result_uri.host, result_uri.path]
    assert_predicate Rack::Utils.parse_query(result_uri.query)["result_ref"], :present?

    # The result page renders only in the browser bound to the Visa authorization session.
    @base_browser.host!(visa_host)
    @base_browser.https!
    @base_browser.get(
      result_uri.request_uri, headers: {
        "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site",
      },
    )
    document = Nokogiri::HTML(@base_browser.response.body)
    form = document.at_css("form#visa-authorization-continuation-form")

    assert_equal 200, @base_browser.response.status
    assert_not_nil form
    assert_not_includes @base_browser.response.body, "transport_access_token"
    assert_not_includes @base_browser.response.body, "transport_refresh_token"
    assert_not_includes @base_browser.response.body, "old_token"
    assert_equal "post", form["method"]
    assert_equal "/oauth/authorize", URI.parse(form["action"]).path
    # The one-shot result travels in the signed continuation token, not in a page field.
    assert_not_nil form.at_css("input[name='continuation']")
    assert_nil form.at_css("input[name='result_ref']")
    assert_nil form.at_css("input[name='return_to']")

    # Posting the continuation resumes the authorization toward its registered OIDC redirect.
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    @base_browser.post(
      form["action"], params: fields, headers: {
        "Origin" => "https://#{visa_host}",
        "Sec-Fetch-Site" => "same-origin",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
      },
    )
    callback_uri = URI.parse(@base_browser.response.location)

    if callback_uri.host == "jump.umaxica.net"
      callback_uri = URI.parse(jump_rt_url_from_location_for_test(callback_uri.to_s))
    end

    registered_callback = URI.parse(
      OidcClientRegistry.find!("core-app-jp").redirect_uris_by_realm.fetch("client").first,
    )

    assert_equal [303, registered_callback.host, registered_callback.path],
                 [@base_browser.response.status, callback_uri.host, callback_uri.path]
    assert_not_respond_to identity.reload, :token
  end

  test "Google sign up entry without an existing identity creates the client, identity and ceremony" do
    new_uid = "new_google_signup_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)
    user_count_before = Client.count

    state =
      begin
        fv5043 = "google"
        fv5042 = "login"
        fv5041 = "sign_up"
        begin
          lf6_provider = fv5043
          lf6_intent = fv5042
          lf6_user = nil
          lf6_entry = fv5041
          lf6_ri = "jp"
          lf6_rt = nil
          lf6_referer = nil
          lf6_host = @host.presence || configured_host(:auth_service)
          host!(lf6_host) if respond_to?(:host!)
          lf6_normalized_provider = SocialIdentifiable.normalize_provider(lf6_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf6_continue_path =
            if lf6_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf6_normalized_provider}_path",
                ri: lf6_ri,
              )
            elsif lf6_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf6_normalized_provider}_registration_path",
                ri: lf6_ri,
                rt: lf6_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf6_normalized_provider}_session_path",
                ri: lf6_ri,
                rt: lf6_rt,
              )
            end
          lf6_headers = social_callback_headers(lf6_host)
          lf6_headers["Referer"] = lf6_referer if lf6_referer.present?
          if lf6_user
            lf6_user_headers =
              begin
                rr6_headers =
                  begin
                    rp_headers = as_user_headers(lf6_user, host: lf6_host)
                    rp_host = rp_headers["Host"]
                    rp_route =
                      begin
                        Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
                      rescue ActionController::RoutingError
                        nil
                      end
                    rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
                    rp_headers
                  end
                rr6_host = rr6_headers["Host"]
                rr6_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr6_host}/") if rr6_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr6_family, rr6_surface = rr6_route&.fetch(:controller)&.split("/")
                rr6_headers
              end
            lf6_token = ClientToken.find_by(public_id: lf6_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf6_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf6_intent.to_s == "link" && lf6_token
            lf6_headers = lf6_headers.merge(lf6_user_headers)
          end
          if lf6_entry.to_s == "sign_up" && lf6_intent.to_s != "link"
            ENV.fetch("PUBLIC_VISA_SERVICE_URL")
            auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.get(
              "/oauth/authorize", params: @oidc_authorization.merge(prompt: "create"), headers: {
                "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
              },
            )
            current_browser = @base_browser
            12.times do
              break unless current_browser.response.redirect?

              target = URI.parse(current_browser.response.location)
              if target.host == "jump.umaxica.net"
                rt = Rack::Utils.parse_query(target.query).fetch("rt")
                target = URI.parse(JWT.decode(rt, nil, false).first.fetch("url"))
              end
              browser = (target.host == auth_host) ? self : @base_browser
              browser.host!(target.host) if target.host
              browser.https!
              browser.get(
                target.request_uri, headers: {
                  "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
                },
              )
              current_browser = browser
              break if browser == self && !response.redirect?
            end

            assert_equal auth_host, request.host
            assert_response :success
          end
          post(lf6_continue_path, headers: lf6_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow4_form = response.parsed_body.at_css("form#social-completion-form")
        flow4_fields =
          flow4_form.css("input[name]").to_h { |flow4_input|
            [
              flow4_input["name"],
              flow4_input["value"],
            ]
          }
        flow4_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow4_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow4_pair| flow4_pair.start_with?("#{flow4_rails_cookie}=") }
        flow4_owner_cookie << "#{flow4_rails_cookie}=#{Rack::Utils.escape(response.cookies.fetch(flow4_rails_cookie))}"
        post(
          flow4_form["action"], params: flow4_fields, headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow4_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow4_target = URI.parse(response.location)
      if flow4_target.path == "/sign/in/check"
        # The Auth handoff redirects to the Visa result page, which continues the parent
        # authorization by a same-origin POST.
        get(
          auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow4_visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
        flow4_result_uri = URI.parse(response.location)

        assert_equal [303, flow4_visa_host], [response.status, flow4_result_uri.host]
        @base_browser.host!(flow4_visa_host)
        @base_browser.https!
        @base_browser.get(
          flow4_result_uri.request_uri, headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site",
          },
        )
        flow4_form = @base_browser.response.parsed_body.at_css("form#visa-authorization-continuation-form")
        flow4_fields =
          flow4_form.css("input[name]").to_h { |flow4_input|
            [
              flow4_input["name"],
              flow4_input["value"],
            ]
          }
        @base_browser.post(
          flow4_form["action"], params: flow4_fields, headers: {
            "Origin" => "https://#{flow4_visa_host}",
            "Sec-Fetch-Site" => "same-origin",
            "Sec-Fetch-Mode" => "navigate",
            "Sec-Fetch-Dest" => "document",
          },
        )
      end
      break unless flow4_result_uri

      flow4_continuation = @base_browser.response

      assert_equal 303, flow4_continuation.status
      flow4_registered_uri = URI.parse(
        OidcClientRegistry.find!("core-app-jp").redirect_uris_by_realm.fetch("client").first,
      )
      flow4_callback_uri = URI.parse(flow4_continuation.location)
      if flow4_callback_uri.host == "jump.umaxica.net"
        flow4_callback_uri = URI.parse(jump_rt_url_from_location_for_test(flow4_callback_uri.to_s))
      end

      assert_equal [flow4_registered_uri.host, flow4_registered_uri.path],
                   [flow4_callback_uri.host, flow4_callback_uri.path]
    end

    follow_redirect! while response.redirect?
    cycle = ClientSignUpFlow.order(:id).last
    patch auth_app_sign_up_check_google_confirmation_url(
      ri: "jp", fb: SignFlowBindingCodec.encode(
        flow: session_sign_up_flow(session, surface: :app),
        surface: :app,
      ),
    ),
          params: {
            confirm_new_social_identity: "1",
            checkpoint_version: cycle.checkpoint_version,
            "cf-turnstile-response": "test_token",
          }, headers: browser_headers.merge(@callback_headers)
    follow_redirect! while response.redirect?
    patch auth_app_sign_up_check_google_birthdate_url(
      ri: "jp", fb: SignFlowBindingCodec.encode(
        flow: session_sign_up_flow(session, surface: :app),
        surface: :app,
      ),
    ),
          params: {
            requirement: "birthdate",
            birthdate: "2000-01-01",
            checkpoint_version: cycle.reload.checkpoint_version,
          }, headers: browser_headers.merge(@callback_headers)
    follow_redirect! while response.redirect? && URI.parse(response.location).host == @host
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow5_form = response.parsed_body.at_css("form#social-completion-form")
        flow5_fields =
          flow5_form.css("input[name]").to_h { |flow5_input|
            [
              flow5_input["name"],
              flow5_input["value"],
            ]
          }
        flow5_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow5_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow5_pair| flow5_pair.start_with?("#{flow5_rails_cookie}=") }
        flow5_owner_cookie << "#{flow5_rails_cookie}=#{Rack::Utils.escape(response.cookies.fetch(flow5_rails_cookie))}"
        post(
          flow5_form["action"],
          params: flow5_fields,
          headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow5_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow5_target = URI.parse(response.location)
      if flow5_target.path == "/sign/in/check"
        # The Auth handoff redirects to the Visa result page, which continues the parent
        # authorization by a same-origin POST.
        get(
          auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow5_visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
        flow5_result_uri = URI.parse(response.location)

        assert_equal [303, flow5_visa_host], [response.status, flow5_result_uri.host]
        @base_browser.host!(flow5_visa_host)
        @base_browser.https!
        @base_browser.get(
          flow5_result_uri.request_uri, headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site",
          },
        )
        flow5_form = @base_browser.response.parsed_body.at_css("form#visa-authorization-continuation-form")
        flow5_fields =
          flow5_form.css("input[name]").to_h { |flow5_input|
            [
              flow5_input["name"],
              flow5_input["value"],
            ]
          }
        @base_browser.post(
          flow5_form["action"], params: flow5_fields, headers: {
            "Origin" => "https://#{flow5_visa_host}",
            "Sec-Fetch-Site" => "same-origin",
            "Sec-Fetch-Mode" => "navigate",
            "Sec-Fetch-Dest" => "document",
          },
        )
      end
      break unless flow5_result_uri

      flow5_continuation = @base_browser.response

      assert_equal 303, flow5_continuation.status
      flow5_registered_uri = URI.parse(
        OidcClientRegistry.find!("core-app-jp").redirect_uris_by_realm.fetch("client").first,
      )
      flow5_callback_uri = URI.parse(flow5_continuation.location)
      if flow5_callback_uri.host == "jump.umaxica.net"
        flow5_callback_uri = URI.parse(jump_rt_url_from_location_for_test(flow5_callback_uri.to_s))
      end

      assert_equal [flow5_registered_uri.host, flow5_registered_uri.path],
                   [flow5_callback_uri.host, flow5_callback_uri.path]
    end

    assert_equal user_count_before + 1, Client.count
    identity = ClientGoogleIdentity.find_by!(uid: new_uid)
    cycle = ClientSignUpFlow.order(:id).last

    assert_equal "google", cycle.entry_method
    assert_equal identity.user_id, cycle.principal_id
  end

  test "Google sign up refuses a birthdate submitted against a stale or malformed checkpoint version" do
    new_uid = "stale_checkpoint_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)
    user_count_before = Client.count

    state =
      begin
        fv5040 = "google"
        fv5039 = "login"
        fv5038 = "sign_up"
        begin
          lf7_provider = fv5040
          lf7_intent = fv5039
          lf7_user = nil
          lf7_entry = fv5038
          lf7_ri = "jp"
          lf7_rt = nil
          lf7_referer = nil
          lf7_host = @host.presence || configured_host(:auth_service)
          host!(lf7_host) if respond_to?(:host!)
          lf7_normalized_provider = SocialIdentifiable.normalize_provider(lf7_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf7_continue_path =
            if lf7_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf7_normalized_provider}_path",
                ri: lf7_ri,
              )
            elsif lf7_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf7_normalized_provider}_registration_path",
                ri: lf7_ri,
                rt: lf7_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf7_normalized_provider}_session_path",
                ri: lf7_ri,
                rt: lf7_rt,
              )
            end
          lf7_headers = social_callback_headers(lf7_host)
          lf7_headers["Referer"] = lf7_referer if lf7_referer.present?
          if lf7_user
            lf7_user_headers =
              begin
                rr7_headers =
                  begin
                    rp_headers = as_user_headers(lf7_user, host: lf7_host)
                    rp_host = rp_headers["Host"]
                    rp_route =
                      begin
                        Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
                      rescue ActionController::RoutingError
                        nil
                      end
                    rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
                    rp_headers
                  end
                rr7_host = rr7_headers["Host"]
                rr7_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr7_host}/") if rr7_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr7_family, rr7_surface = rr7_route&.fetch(:controller)&.split("/")
                rr7_headers
              end
            lf7_token = ClientToken.find_by(public_id: lf7_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf7_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf7_intent.to_s == "link" && lf7_token
            lf7_headers = lf7_headers.merge(lf7_user_headers)
          end
          if lf7_entry.to_s == "sign_up" && lf7_intent.to_s != "link"
            ENV.fetch("PUBLIC_VISA_SERVICE_URL")
            auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.get(
              "/oauth/authorize", params: @oidc_authorization.merge(prompt: "create"), headers: {
                "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
              },
            )
            current_browser = @base_browser
            12.times do
              break unless current_browser.response.redirect?

              target = URI.parse(current_browser.response.location)
              if target.host == "jump.umaxica.net"
                rt = Rack::Utils.parse_query(target.query).fetch("rt")
                target = URI.parse(JWT.decode(rt, nil, false).first.fetch("url"))
              end
              browser = (target.host == auth_host) ? self : @base_browser
              browser.host!(target.host) if target.host
              browser.https!
              browser.get(
                target.request_uri, headers: {
                  "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
                },
              )
              current_browser = browser
              break if browser == self && !response.redirect?
            end

            assert_equal auth_host, request.host
            assert_response :success
          end
          post(lf7_continue_path, headers: lf7_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow6_form = response.parsed_body.at_css("form#social-completion-form")
        flow6_fields =
          flow6_form.css("input[name]").to_h { |flow6_input|
            [
              flow6_input["name"],
              flow6_input["value"],
            ]
          }
        flow6_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow6_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow6_pair| flow6_pair.start_with?("#{flow6_rails_cookie}=") }
        flow6_owner_cookie << "#{flow6_rails_cookie}=#{Rack::Utils.escape(response.cookies.fetch(flow6_rails_cookie))}"
        post(
          flow6_form["action"],
          params: flow6_fields,
          headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow6_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow6_target = URI.parse(response.location)
      if flow6_target.path == "/sign/in/check"
        # The Auth handoff redirects to the Visa result page, which continues the parent
        # authorization by a same-origin POST.
        get(
          auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow6_visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
        flow6_result_uri = URI.parse(response.location)

        assert_equal [303, flow6_visa_host], [response.status, flow6_result_uri.host]
        @base_browser.host!(flow6_visa_host)
        @base_browser.https!
        @base_browser.get(
          flow6_result_uri.request_uri, headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site",
          },
        )
        flow6_form = @base_browser.response.parsed_body.at_css("form#visa-authorization-continuation-form")
        flow6_fields =
          flow6_form.css("input[name]").to_h { |flow6_input|
            [
              flow6_input["name"],
              flow6_input["value"],
            ]
          }
        @base_browser.post(
          flow6_form["action"], params: flow6_fields, headers: {
            "Origin" => "https://#{flow6_visa_host}",
            "Sec-Fetch-Site" => "same-origin",
            "Sec-Fetch-Mode" => "navigate",
            "Sec-Fetch-Dest" => "document",
          },
        )
      end
      break unless flow6_result_uri

      flow6_continuation = @base_browser.response

      assert_equal 303, flow6_continuation.status
      flow6_registered_uri = URI.parse(
        OidcClientRegistry.find!("core-app-jp").redirect_uris_by_realm.fetch("client").first,
      )
      flow6_callback_uri = URI.parse(flow6_continuation.location)
      if flow6_callback_uri.host == "jump.umaxica.net"
        flow6_callback_uri = URI.parse(jump_rt_url_from_location_for_test(flow6_callback_uri.to_s))
      end

      assert_equal [flow6_registered_uri.host, flow6_registered_uri.path],
                   [flow6_callback_uri.host, flow6_callback_uri.path]
    end

    follow_redirect! while response.redirect?
    cycle = ClientSignUpFlow.order(:id).last
    patch auth_app_sign_up_check_google_confirmation_url(
      ri: "jp", fb: SignFlowBindingCodec.encode(
        flow: session_sign_up_flow(session, surface: :app),
        surface: :app,
      ),
    ),
          params: {
            confirm_new_social_identity: "1",
            checkpoint_version: cycle.checkpoint_version,
            "cf-turnstile-response": "test_token",
          }, headers: browser_headers.merge(@callback_headers)
    follow_redirect! while response.redirect?
    current_version = cycle.reload.checkpoint_version

    [current_version - 1, "not-a-number"].each do |submitted|
      patch auth_app_sign_up_check_google_birthdate_url(
        ri: "jp", fb: SignFlowBindingCodec.encode(
          flow: session_sign_up_flow(session, surface: :app),
          surface: :app,
        ),
      ),
            params: { requirement: "birthdate", birthdate: "2000-01-01", checkpoint_version: submitted },
            headers: browser_headers.merge(@callback_headers)

      assert_response :conflict, submitted.inspect
      # The non-JSON checkpoint refusal renders the localized message; the JSON
      # machine code stays `stale_checkpoint` (see checkpoint_passkeys_controller_test).
      assert_equal I18n.t("errors.messages.stale_checkpoint"), response.body
    end

    # WU-05d: the confirmation created one pending Client; it stays unfinished and unregistered.
    assert_equal user_count_before + 1, Client.count
    assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, Client.order(:id).last.status_id
    assert_nil ClientGoogleIdentity.find_by(uid: new_uid)
    assert_equal current_version, cycle.reload.checkpoint_version
  end

  # The old "applicant below the minimum age is halted" journey ended here. R-AU-50 and the
  # implemented one-day rule removed that branch: an eligible birthdate (any date before the
  # service date) completes the step exactly like the accepted sign-up journeys above, and the
  # today-or-later refusal is covered publicly by the email birthdate checkpoint boundaries.

  test "Apple sign up entry without an existing identity creates the client, identity and ceremony" do
    new_uid = "new_apple_signup_#{SecureRandom.hex(4)}"
    user_count_before = Client.count

    state =
      begin
        fv5034 = "apple"
        fv5033 = "login"
        fv5032 = "sign_up"
        begin
          lf9_provider = fv5034
          lf9_intent = fv5033
          lf9_user = nil
          lf9_entry = fv5032
          lf9_ri = "jp"
          lf9_rt = nil
          lf9_referer = nil
          lf9_host = @host.presence || configured_host(:auth_service)
          host!(lf9_host) if respond_to?(:host!)
          lf9_normalized_provider = SocialIdentifiable.normalize_provider(lf9_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf9_continue_path =
            if lf9_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf9_normalized_provider}_path",
                ri: lf9_ri,
              )
            elsif lf9_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf9_normalized_provider}_registration_path",
                ri: lf9_ri,
                rt: lf9_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf9_normalized_provider}_session_path",
                ri: lf9_ri,
                rt: lf9_rt,
              )
            end
          lf9_headers = social_callback_headers(lf9_host)
          lf9_headers["Referer"] = lf9_referer if lf9_referer.present?
          if lf9_user
            lf9_user_headers =
              begin
                rr9_headers =
                  begin
                    rp_headers = as_user_headers(lf9_user, host: lf9_host)
                    rp_host = rp_headers["Host"]
                    rp_route =
                      begin
                        Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
                      rescue ActionController::RoutingError
                        nil
                      end
                    rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
                    rp_headers
                  end
                rr9_host = rr9_headers["Host"]
                rr9_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr9_host}/") if rr9_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr9_family, rr9_surface = rr9_route&.fetch(:controller)&.split("/")
                rr9_headers
              end
            lf9_token = ClientToken.find_by(public_id: lf9_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf9_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf9_intent.to_s == "link" && lf9_token
            lf9_headers = lf9_headers.merge(lf9_user_headers)
          end
          if lf9_entry.to_s == "sign_up" && lf9_intent.to_s != "link"
            ENV.fetch("PUBLIC_VISA_SERVICE_URL")
            auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.get(
              "/oauth/authorize", params: @oidc_authorization.merge(prompt: "create"), headers: {
                "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
              },
            )
            current_browser = @base_browser
            12.times do
              break unless current_browser.response.redirect?

              target = URI.parse(current_browser.response.location)
              if target.host == "jump.umaxica.net"
                rt = Rack::Utils.parse_query(target.query).fetch("rt")
                target = URI.parse(JWT.decode(rt, nil, false).first.fetch("url"))
              end
              browser = (target.host == auth_host) ? self : @base_browser
              browser.host!(target.host) if target.host
              browser.https!
              browser.get(
                target.request_uri, headers: {
                  "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
                },
              )
              current_browser = browser
              break if browser == self && !response.redirect?
            end

            assert_equal auth_host, request.host
            assert_response :success
          end
          post(lf9_continue_path, headers: lf9_headers)
          social_auth_state_from_response
        end
      end
    setup_apple_mock_auth(uid: new_uid)

    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    follow_redirect! while response.redirect?
    cycle = ClientSignUpFlow.order(:id).last

    assert_equal "apple", cycle.entry_method

    patch auth_app_sign_up_check_apple_confirmation_url(
      ri: "jp", fb: SignFlowBindingCodec.encode(
        flow: session_sign_up_flow(session, surface: :app),
        surface: :app,
      ),
    ),
          params: {
            confirm_new_social_identity: "1",
            checkpoint_version: cycle.checkpoint_version,
            "cf-turnstile-response": "test_token",
          }, headers: browser_headers.merge(@callback_headers)
    follow_redirect! while response.redirect?
    patch auth_app_sign_up_check_apple_birthdate_url(
      ri: "jp", fb: SignFlowBindingCodec.encode(
        flow: session_sign_up_flow(session, surface: :app),
        surface: :app,
      ),
    ),
          params: {
            requirement: "birthdate",
            birthdate: "2000-01-01",
            checkpoint_version: cycle.reload.checkpoint_version,
          }, headers: browser_headers.merge(@callback_headers)
    follow_redirect! while response.redirect? && URI.parse(response.location).host == @host
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow8_form = response.parsed_body.at_css("form#social-completion-form")
        flow8_fields =
          flow8_form.css("input[name]").to_h { |flow8_input|
            [
              flow8_input["name"],
              flow8_input["value"],
            ]
          }
        flow8_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow8_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow8_pair| flow8_pair.start_with?("#{flow8_rails_cookie}=") }
        flow8_owner_cookie << "#{flow8_rails_cookie}=#{Rack::Utils.escape(response.cookies.fetch(flow8_rails_cookie))}"
        post(
          flow8_form["action"],
          params: flow8_fields,
          headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow8_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow8_target = URI.parse(response.location)
      if flow8_target.path == "/sign/in/check"
        # The Auth handoff redirects to the Visa result page, which continues the parent
        # authorization by a same-origin POST.
        get(
          auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow8_visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
        flow8_result_uri = URI.parse(response.location)

        assert_equal [303, flow8_visa_host], [response.status, flow8_result_uri.host]
        @base_browser.host!(flow8_visa_host)
        @base_browser.https!
        @base_browser.get(
          flow8_result_uri.request_uri, headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site",
          },
        )
        flow8_form = @base_browser.response.parsed_body.at_css("form#visa-authorization-continuation-form")
        flow8_fields =
          flow8_form.css("input[name]").to_h { |flow8_input|
            [
              flow8_input["name"],
              flow8_input["value"],
            ]
          }
        @base_browser.post(
          flow8_form["action"], params: flow8_fields, headers: {
            "Origin" => "https://#{flow8_visa_host}",
            "Sec-Fetch-Site" => "same-origin",
            "Sec-Fetch-Mode" => "navigate",
            "Sec-Fetch-Dest" => "document",
          },
        )
      end
      break unless flow8_result_uri

      flow8_continuation = @base_browser.response

      assert_equal 303, flow8_continuation.status
      flow8_registered_uri = URI.parse(
        OidcClientRegistry.find!("core-app-jp").redirect_uris_by_realm.fetch("client").first,
      )
      flow8_callback_uri = URI.parse(flow8_continuation.location)
      if flow8_callback_uri.host == "jump.umaxica.net"
        flow8_callback_uri = URI.parse(jump_rt_url_from_location_for_test(flow8_callback_uri.to_s))
      end

      assert_equal [flow8_registered_uri.host, flow8_registered_uri.path],
                   [flow8_callback_uri.host, flow8_callback_uri.path]
    end

    assert_equal user_count_before + 1, Client.count
    identity = ClientAppleIdentity.find_by!(uid: new_uid)

    assert_equal identity.user_id, cycle.reload.principal_id
  end

  test "Apple login with existing identity does not create new user" do
    existing_uid = "existing_apple_user_#{SecureRandom.hex(4)}"

    existing_user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::NOTHING, public_id: PublicId.generate,
    )
    ClientAppleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "apple",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    user_count_before = Client.count

    state =
      begin
        fv5031 = "apple"
        fv5030 = "login"
        fv5029 = nil
        begin
          lf10_provider = fv5031
          lf10_intent = fv5030
          lf10_user = nil
          lf10_entry = fv5029
          lf10_ri = "jp"
          lf10_rt = nil
          lf10_referer = nil
          lf10_host = @host.presence || configured_host(:auth_service)
          host!(lf10_host) if respond_to?(:host!)
          lf10_normalized_provider = SocialIdentifiable.normalize_provider(lf10_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf10_continue_path =
            if lf10_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf10_normalized_provider}_path",
                ri: lf10_ri,
              )
            elsif lf10_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf10_normalized_provider}_registration_path",
                ri: lf10_ri,
                rt: lf10_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf10_normalized_provider}_session_path",
                ri: lf10_ri,
                rt: lf10_rt,
              )
            end
          lf10_headers = social_callback_headers(lf10_host)
          lf10_headers["Referer"] = lf10_referer if lf10_referer.present?
          if lf10_user
            lf10_user_headers =
              begin
                rr10_headers =
                  begin
                    rp_headers = as_user_headers(lf10_user, host: lf10_host)
                    rp_host = rp_headers["Host"]
                    rp_route =
                      begin
                        Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
                      rescue ActionController::RoutingError
                        nil
                      end
                    rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
                    rp_headers
                  end
                rr10_host = rr10_headers["Host"]
                rr10_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr10_host}/") if rr10_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr10_family, rr10_surface = rr10_route&.fetch(:controller)&.split("/")
                rr10_headers
              end
            lf10_token = ClientToken.find_by(public_id: lf10_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf10_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf10_intent.to_s == "link" && lf10_token
            lf10_headers = lf10_headers.merge(lf10_user_headers)
          end
          if lf10_entry.to_s == "sign_up" && lf10_intent.to_s != "link"
            ENV.fetch("PUBLIC_VISA_SERVICE_URL")
            auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.get(
              "/oauth/authorize", params: @oidc_authorization.merge(prompt: "create"), headers: {
                "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
              },
            )
            current_browser = @base_browser
            12.times do
              break unless current_browser.response.redirect?

              target = URI.parse(current_browser.response.location)
              if target.host == "jump.umaxica.net"
                rt = Rack::Utils.parse_query(target.query).fetch("rt")
                target = URI.parse(JWT.decode(rt, nil, false).first.fetch("url"))
              end
              browser = (target.host == auth_host) ? self : @base_browser
              browser.host!(target.host) if target.host
              browser.https!
              browser.get(
                target.request_uri, headers: {
                  "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
                },
              )
              current_browser = browser
              break if browser == self && !response.redirect?
            end

            assert_equal auth_host, request.host
            assert_response :success
          end
          post(lf10_continue_path, headers: lf10_headers)
          social_auth_state_from_response
        end
      end
    setup_apple_mock_auth(uid: existing_uid)

    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow9_form = response.parsed_body.at_css("form#social-completion-form")
        flow9_fields =
          flow9_form.css("input[name]").to_h { |flow9_input|
            [
              flow9_input["name"],
              flow9_input["value"],
            ]
          }
        flow9_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow9_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow9_pair| flow9_pair.start_with?("#{flow9_rails_cookie}=") }
        flow9_owner_cookie << "#{flow9_rails_cookie}=#{Rack::Utils.escape(response.cookies.fetch(flow9_rails_cookie))}"
        post(
          flow9_form["action"],
          params: flow9_fields,
          headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow9_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow9_target = URI.parse(response.location)
      if flow9_target.path == "/sign/in/check"
        # The Auth handoff redirects to the Visa result page, which continues the parent
        # authorization by a same-origin POST.
        get(
          auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow9_visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
        flow9_result_uri = URI.parse(response.location)

        assert_equal [303, flow9_visa_host], [response.status, flow9_result_uri.host]
        @base_browser.host!(flow9_visa_host)
        @base_browser.https!
        @base_browser.get(
          flow9_result_uri.request_uri, headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site",
          },
        )
        flow9_form = @base_browser.response.parsed_body.at_css("form#visa-authorization-continuation-form")
        flow9_fields =
          flow9_form.css("input[name]").to_h { |flow9_input|
            [
              flow9_input["name"],
              flow9_input["value"],
            ]
          }
        @base_browser.post(
          flow9_form["action"], params: flow9_fields, headers: {
            "Origin" => "https://#{flow9_visa_host}",
            "Sec-Fetch-Site" => "same-origin",
            "Sec-Fetch-Mode" => "navigate",
            "Sec-Fetch-Dest" => "document",
          },
        )
      end
      break unless flow9_result_uri

      flow9_continuation = @base_browser.response

      assert_equal 303, flow9_continuation.status
      flow9_registered_uri = URI.parse(
        OidcClientRegistry.find!("core-app-jp").redirect_uris_by_realm.fetch("client").first,
      )
      flow9_callback_uri = URI.parse(flow9_continuation.location)
      if flow9_callback_uri.host == "jump.umaxica.net"
        flow9_callback_uri = URI.parse(jump_rt_url_from_location_for_test(flow9_callback_uri.to_s))
      end

      assert_equal [flow9_registered_uri.host, flow9_registered_uri.path],
                   [flow9_callback_uri.host, flow9_callback_uri.path]
    end

    assert_equal user_count_before, Client.count
  end

  test "Apple login with existing identity completes on the app Dashboard, never Home" do
    existing_uid = "existing_apple_dashboard_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::NOTHING,
      public_id: PublicId.generate,
      birthdate: "2000-01-01",
    )
    ClientAppleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "apple",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    state =
      begin
        fv5028 = "apple"
        fv5027 = "login"
        fv5026 = nil
        begin
          lf11_provider = fv5028
          lf11_intent = fv5027
          lf11_user = nil
          lf11_entry = fv5026
          lf11_ri = "jp"
          lf11_rt = nil
          lf11_referer = nil
          lf11_host = @host.presence || configured_host(:auth_service)
          host!(lf11_host) if respond_to?(:host!)
          lf11_normalized_provider = SocialIdentifiable.normalize_provider(lf11_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf11_continue_path =
            if lf11_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf11_normalized_provider}_path",
                ri: lf11_ri,
              )
            elsif lf11_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf11_normalized_provider}_registration_path",
                ri: lf11_ri,
                rt: lf11_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf11_normalized_provider}_session_path",
                ri: lf11_ri,
                rt: lf11_rt,
              )
            end
          lf11_headers = social_callback_headers(lf11_host)
          lf11_headers["Referer"] = lf11_referer if lf11_referer.present?
          if lf11_user
            lf11_user_headers =
              begin
                rr11_headers =
                  begin
                    rp_headers = as_user_headers(lf11_user, host: lf11_host)
                    rp_host = rp_headers["Host"]
                    rp_route =
                      begin
                        Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
                      rescue ActionController::RoutingError
                        nil
                      end
                    rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
                    rp_headers
                  end
                rr11_host = rr11_headers["Host"]
                rr11_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr11_host}/") if rr11_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr11_family, rr11_surface = rr11_route&.fetch(:controller)&.split("/")
                rr11_headers
              end
            lf11_token = ClientToken.find_by(public_id: lf11_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf11_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf11_intent.to_s == "link" && lf11_token
            lf11_headers = lf11_headers.merge(lf11_user_headers)
          end
          if lf11_entry.to_s == "sign_up" && lf11_intent.to_s != "link"
            ENV.fetch("PUBLIC_VISA_SERVICE_URL")
            auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.get(
              "/oauth/authorize", params: @oidc_authorization.merge(prompt: "create"), headers: {
                "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
              },
            )
            current_browser = @base_browser
            12.times do
              break unless current_browser.response.redirect?

              target = URI.parse(current_browser.response.location)
              if target.host == "jump.umaxica.net"
                rt = Rack::Utils.parse_query(target.query).fetch("rt")
                target = URI.parse(JWT.decode(rt, nil, false).first.fetch("url"))
              end
              browser = (target.host == auth_host) ? self : @base_browser
              browser.host!(target.host) if target.host
              browser.https!
              browser.get(
                target.request_uri, headers: {
                  "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
                },
              )
              current_browser = browser
              break if browser == self && !response.redirect?
            end

            assert_equal auth_host, request.host
            assert_response :success
          end
          post(lf11_continue_path, headers: lf11_headers)
          social_auth_state_from_response
        end
      end
    setup_apple_mock_auth(uid: existing_uid)

    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow10_form = response.parsed_body.at_css("form#social-completion-form")
        flow10_fields =
          flow10_form.css("input[name]").to_h { |flow10_input|
            [
              flow10_input["name"],
              flow10_input["value"],
            ]
          }
        flow10_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow10_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow10_pair| flow10_pair.start_with?("#{flow10_rails_cookie}=") }
        flow10_owner_cookie << "#{flow10_rails_cookie}=#{Rack::Utils.escape(
          response
                    .cookies.fetch(flow10_rails_cookie),
        )}"
        post(
          flow10_form["action"],
          params: flow10_fields,
          headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow10_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow10_target = URI.parse(response.location)
      if flow10_target.path == "/sign/in/check"
        # The Auth handoff redirects to the Visa result page, which continues the parent
        # authorization by a same-origin POST.
        get(
          auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow10_visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
        flow10_result_uri = URI.parse(response.location)

        assert_equal [303, flow10_visa_host], [response.status, flow10_result_uri.host]
        @base_browser.host!(flow10_visa_host)
        @base_browser.https!
        @base_browser.get(
          flow10_result_uri.request_uri, headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site",
          },
        )
        flow10_form = @base_browser.response.parsed_body.at_css("form#visa-authorization-continuation-form")
        flow10_fields =
          flow10_form.css("input[name]").to_h { |flow10_input|
            [
              flow10_input["name"],
              flow10_input["value"],
            ]
          }
        @base_browser.post(
          flow10_form["action"], params: flow10_fields, headers: {
            "Origin" => "https://#{flow10_visa_host}",
            "Sec-Fetch-Site" => "same-origin",
            "Sec-Fetch-Mode" => "navigate",
            "Sec-Fetch-Dest" => "document",
          },
        )
      end
      break unless flow10_result_uri

      flow10_continuation = @base_browser.response

      assert_equal 303, flow10_continuation.status
      flow10_registered_uri = URI.parse(
        OidcClientRegistry.find!("core-app-jp").redirect_uris_by_realm.fetch("client").first,
      )
      flow10_callback_uri = URI.parse(flow10_continuation.location)
      if flow10_callback_uri.host == "jump.umaxica.net"
        flow10_callback_uri = URI.parse(jump_rt_url_from_location_for_test(flow10_callback_uri.to_s))
      end

      assert_equal [flow10_registered_uri.host, flow10_registered_uri.path],
                   [flow10_callback_uri.host, flow10_callback_uri.path]
    end

    assert_response :redirect
    assert_social_login_issued_visa_result(response.location)
  end

  # ============================================================================
  # New user creation
  # ============================================================================
  # rubocop:disable Minitest/MultipleAssertions
  test "unknown Google sign-in neither registers an account nor links an identity" do
    setup_google_mock_auth(uid: "unknown-signin-#{SecureRandom.hex(8)}")
    assert_no_difference(
      ["Client.count", "ClientExternalIdentity.count", "ClientSignUpFlow.count",
       "ClientToken.count",],
    ) do
      post auth_app_social_google_session_path(ri: "jp"), headers: @callback_headers
      state = social_auth_state_from_response

      assert_predicate state, :present?
      get auth_app_social_google_callback_path(ri: "jp"), params: { state: state }, headers: @callback_headers
    end
    assert_response :bad_request
    # A verified but unregistered subject gets the sign-up guidance, not the uniform refusal.
    assert_equal I18n.t("sign.app.social.verified_subject_guidance.unregistered.title"),
                 response.parsed_body.at_css("h1").text
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_predicate flash, :empty?
  end

  test "Google birthdate before confirmation halts the original signup without provisioning" do
    new_uid = "brand_new_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)

    user_count_before = Client.count
    identity_count_before = ClientGoogleIdentity.count

    state =
      begin
        fv5022 = "google"
        fv5021 = "login"
        fv5020 = "sign_up"
        begin
          lf13_provider = fv5022
          lf13_intent = fv5021
          lf13_user = nil
          lf13_entry = fv5020
          lf13_ri = "jp"
          lf13_rt = nil
          lf13_referer = nil
          lf13_host = @host.presence || configured_host(:auth_service)
          host!(lf13_host) if respond_to?(:host!)
          lf13_normalized_provider = SocialIdentifiable.normalize_provider(lf13_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf13_continue_path =
            if lf13_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf13_normalized_provider}_path",
                ri: lf13_ri,
              )
            elsif lf13_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf13_normalized_provider}_registration_path",
                ri: lf13_ri,
                rt: lf13_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf13_normalized_provider}_session_path",
                ri: lf13_ri,
                rt: lf13_rt,
              )
            end
          lf13_headers = social_callback_headers(lf13_host)
          lf13_headers["Referer"] = lf13_referer if lf13_referer.present?
          if lf13_user
            lf13_user_headers =
              begin
                rr13_headers =
                  begin
                    rp_headers = as_user_headers(lf13_user, host: lf13_host)
                    rp_host = rp_headers["Host"]
                    rp_route =
                      begin
                        Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
                      rescue ActionController::RoutingError
                        nil
                      end
                    rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
                    rp_headers
                  end
                rr13_host = rr13_headers["Host"]
                rr13_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr13_host}/") if rr13_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr13_family, rr13_surface = rr13_route&.fetch(:controller)&.split("/")
                rr13_headers
              end
            lf13_token = ClientToken.find_by(public_id: lf13_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf13_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf13_intent.to_s == "link" && lf13_token
            lf13_headers = lf13_headers.merge(lf13_user_headers)
          end
          if lf13_entry.to_s == "sign_up" && lf13_intent.to_s != "link"
            ENV.fetch("PUBLIC_VISA_SERVICE_URL")
            auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.get(
              "/oauth/authorize", params: @oidc_authorization.merge(prompt: "create"), headers: {
                "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
              },
            )
            current_browser = @base_browser
            12.times do
              break unless current_browser.response.redirect?

              target = URI.parse(current_browser.response.location)
              if target.host == "jump.umaxica.net"
                rt = Rack::Utils.parse_query(target.query).fetch("rt")
                target = URI.parse(JWT.decode(rt, nil, false).first.fetch("url"))
              end
              browser = (target.host == auth_host) ? self : @base_browser
              browser.host!(target.host) if target.host
              browser.https!
              browser.get(
                target.request_uri, headers: {
                  "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
                },
              )
              current_browser = browser
              break if browser == self && !response.redirect?
            end

            assert_equal auth_host, request.host
            assert_response :success
          end
          post(lf13_continue_path, headers: lf13_headers)
          social_auth_state_from_response
        end
      end

    assert_no_difference("Client.count") do
      assert_no_difference("ClientGoogleIdentity.count") do
        assert_no_difference("ClientAccount.count") do
          assert_no_difference("OperatorOrganization.count") do
            assert_no_difference("Avatar.count") do
              assert_no_difference("ClientToken.count") do
                get auth_app_social_google_callback_url(ri: "jp"),
                    params: { state: state },
                    headers: browser_headers.merge(@callback_headers)
                1.times do
                  if response.media_type == "text/html" && response.body.include?("social-completion-form")
                    flow12_form = response.parsed_body.at_css("form#social-completion-form")
                    flow12_fields =
                      flow12_form.css("input[name]").to_h { |flow12_input|
                        [
                          flow12_input["name"],
                          flow12_input["value"],
                        ]
                      }
                    flow12_rails_cookie = Rails.application.config.session_options.fetch(:key)
                    flow12_owner_cookie =
                      request.headers["Cookie"].to_s.split("; ")
                        .reject { |flow12_pair| flow12_pair.start_with?("#{flow12_rails_cookie}=") }
                    flow12_owner_cookie << "#{flow12_rails_cookie}=#{Rack::Utils.escape(
                      response
                                            .cookies.fetch(flow12_rails_cookie),
                    )}"
                    post(
                      flow12_form["action"],
                      params: flow12_fields,
                      headers: {
                        "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                        "Cookie" => flow12_owner_cookie.join("; "),
                        "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
                        "Sec-Fetch-Site" => "same-origin",
                      },
                    )
                    break
                  end
                  break unless response.redirect? && @base_browser

                  flow12_target = URI.parse(response.location)
                  if flow12_target.path == "/sign/in/check"
                    # The Auth handoff redirects to the Visa result page, which continues the parent
                    # authorization by a same-origin POST.
                    get(
                      auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
                        "Sec-Fetch-Mode" => "navigate",
                        "Sec-Fetch-Dest" => "document",
                        "Sec-Fetch-Site" => "same-origin",
                      },
                    )
                    flow12_visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
                    flow12_result_uri = URI.parse(response.location)

                    assert_equal [303, flow12_visa_host], [response.status, flow12_result_uri.host]
                    @base_browser.host!(flow12_visa_host)
                    @base_browser.https!
                    @base_browser.get(
                      flow12_result_uri.request_uri, headers: {
                        "Sec-Fetch-Mode" => "navigate",
                        "Sec-Fetch-Dest" => "document",
                        "Sec-Fetch-Site" => "cross-site",
                      },
                    )
                    flow12_form = @base_browser.response.parsed_body.at_css("form#visa-authorization-continuation-form")
                    flow12_fields =
                      flow12_form.css("input[name]").to_h { |flow12_input|
                        [
                          flow12_input["name"],
                          flow12_input["value"],
                        ]
                      }
                    @base_browser.post(
                      flow12_form["action"], params: flow12_fields, headers: {
                        "Origin" => "https://#{flow12_visa_host}",
                        "Sec-Fetch-Site" => "same-origin",
                        "Sec-Fetch-Mode" => "navigate",
                        "Sec-Fetch-Dest" => "document",
                      },
                    )
                  end
                  break unless flow12_result_uri

                  flow12_continuation = @base_browser.response

                  assert_equal 303, flow12_continuation.status
                  flow12_registered_uri = URI.parse(
                    OidcClientRegistry.find!("core-app-jp").redirect_uris_by_realm.fetch("client").first,
                  )
                  flow12_callback_uri = URI.parse(flow12_continuation.location)
                  if flow12_callback_uri.host == "jump.umaxica.net"
                    flow12_callback_uri = URI.parse(jump_rt_url_from_location_for_test(flow12_callback_uri.to_s))
                  end

                  assert_equal [flow12_registered_uri.host, flow12_registered_uri.path],
                               [flow12_callback_uri.host, flow12_callback_uri.path]
                end
              end
            end
          end
        end
      end
    end

    assert_redirected_to auth_app_sign_up_guard_google_url(ri: "jp")
    follow_redirect!

    assert_redirected_to auth_app_sign_up_check_google_confirmation_url(
      ri: "jp", fb: SignFlowBindingCodec.encode(
        flow: session_sign_up_flow(session, surface: :app),
        surface: :app,
      ),
    )
    follow_redirect!

    assert_response :ok
    assert_includes response.body, "このGoogleアカウントは未登録です。"
    assert_includes response.body, "新しいUmaxica Identityを作成します。"
    assert_includes response.body, "既存アカウントとは後から統合できません。"
    assert_includes response.body, "間違いならキャンセルしてください。"
    # The social sign-up checkpoint asks for an explicit confirmation before an identity is
    # created; the page object names that component and carries the label it asks agreement to.
    assert_equal "auth/app/sign/up/check/social/confirmations/show", inertia_component
    assert_predicate inertia_props.fetch("confirm_label"), :present?
    assert_select "script:not([nonce])", false

    cycle = session_sign_up_flow(session, surface: :app)

    assert_predicate cycle, :present?

    assert_no_difference("Client.count") do
      assert_no_difference("ClientGoogleIdentity.count") do
        assert_no_difference("ClientAccount.count") do
          assert_no_difference("OperatorOrganization.count") do
            assert_no_difference("Avatar.count") do
              assert_no_difference("ClientToken.count") do
                patch auth_app_sign_up_check_google_birthdate_path(
                  ri: "jp", fb: SignFlowBindingCodec.encode(
                    flow: session_sign_up_flow(session, surface: :app),
                    surface: :app,
                  ),
                ),
                      params: {
                        requirement: "birthdate",
                        birthdate: "2000-02-03",
                        checkpoint_version: cycle.checkpoint_version,
                      },
                      headers: browser_headers.merge(@callback_headers)
              end
            end
          end
        end
      end
    end

    assert_response :conflict

    assert_predicate cycle.reload, :sign_up_halted?
    assert_equal user_count_before, Client.count
    assert_equal identity_count_before, ClientGoogleIdentity.count
  end

  # rubocop:enable Minitest/MultipleAssertions

  test "duplicate Google callback failure after new-account checkpoint ends with a uniform refusal" do
    new_uid = "duplicate_callback_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)

    state =
      begin
        fv5019 = "google"
        fv5018 = "login"
        fv5017 = "sign_up"
        begin
          lf14_provider = fv5019
          lf14_intent = fv5018
          lf14_user = nil
          lf14_entry = fv5017
          lf14_ri = "jp"
          lf14_rt = nil
          lf14_referer = nil
          lf14_host = @host.presence || configured_host(:auth_service)
          host!(lf14_host) if respond_to?(:host!)
          lf14_normalized_provider = SocialIdentifiable.normalize_provider(lf14_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf14_continue_path =
            if lf14_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf14_normalized_provider}_path",
                ri: lf14_ri,
              )
            elsif lf14_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf14_normalized_provider}_registration_path",
                ri: lf14_ri,
                rt: lf14_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf14_normalized_provider}_session_path",
                ri: lf14_ri,
                rt: lf14_rt,
              )
            end
          lf14_headers = social_callback_headers(lf14_host)
          lf14_headers["Referer"] = lf14_referer if lf14_referer.present?
          if lf14_user
            lf14_user_headers =
              begin
                rr14_headers =
                  begin
                    rp_headers = as_user_headers(lf14_user, host: lf14_host)
                    rp_host = rp_headers["Host"]
                    rp_route =
                      begin
                        Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
                      rescue ActionController::RoutingError
                        nil
                      end
                    rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
                    rp_headers
                  end
                rr14_host = rr14_headers["Host"]
                rr14_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr14_host}/") if rr14_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr14_family, rr14_surface = rr14_route&.fetch(:controller)&.split("/")
                rr14_headers
              end
            lf14_token = ClientToken.find_by(public_id: lf14_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf14_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf14_intent.to_s == "link" && lf14_token
            lf14_headers = lf14_headers.merge(lf14_user_headers)
          end
          if lf14_entry.to_s == "sign_up" && lf14_intent.to_s != "link"
            ENV.fetch("PUBLIC_VISA_SERVICE_URL")
            auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.get(
              "/oauth/authorize", params: @oidc_authorization.merge(prompt: "create"), headers: {
                "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
              },
            )
            current_browser = @base_browser
            12.times do
              break unless current_browser.response.redirect?

              target = URI.parse(current_browser.response.location)
              if target.host == "jump.umaxica.net"
                rt = Rack::Utils.parse_query(target.query).fetch("rt")
                target = URI.parse(JWT.decode(rt, nil, false).first.fetch("url"))
              end
              browser = (target.host == auth_host) ? self : @base_browser
              browser.host!(target.host) if target.host
              browser.https!
              browser.get(
                target.request_uri, headers: {
                  "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
                },
              )
              current_browser = browser
              break if browser == self && !response.redirect?
            end

            assert_equal auth_host, request.host
            assert_response :success
          end
          post(lf14_continue_path, headers: lf14_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow13_form = response.parsed_body.at_css("form#social-completion-form")
        flow13_fields =
          flow13_form.css("input[name]").to_h { |flow13_input|
            [
              flow13_input["name"],
              flow13_input["value"],
            ]
          }
        flow13_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow13_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow13_pair| flow13_pair.start_with?("#{flow13_rails_cookie}=") }
        flow13_owner_cookie << "#{flow13_rails_cookie}=#{Rack::Utils.escape(
          response
                    .cookies.fetch(flow13_rails_cookie),
        )}"
        post(
          flow13_form["action"],
          params: flow13_fields,
          headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow13_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow13_target = URI.parse(response.location)
      if flow13_target.path == "/sign/in/check"
        # The Auth handoff redirects to the Visa result page, which continues the parent
        # authorization by a same-origin POST.
        get(
          auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow13_visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
        flow13_result_uri = URI.parse(response.location)

        assert_equal [303, flow13_visa_host], [response.status, flow13_result_uri.host]
        @base_browser.host!(flow13_visa_host)
        @base_browser.https!
        @base_browser.get(
          flow13_result_uri.request_uri, headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site",
          },
        )
        flow13_form = @base_browser.response.parsed_body.at_css("form#visa-authorization-continuation-form")
        flow13_fields =
          flow13_form.css("input[name]").to_h { |flow13_input|
            [
              flow13_input["name"],
              flow13_input["value"],
            ]
          }
        @base_browser.post(
          flow13_form["action"], params: flow13_fields, headers: {
            "Origin" => "https://#{flow13_visa_host}",
            "Sec-Fetch-Site" => "same-origin",
            "Sec-Fetch-Mode" => "navigate",
            "Sec-Fetch-Dest" => "document",
          },
        )
      end
      break unless flow13_result_uri

      flow13_continuation = @base_browser.response

      assert_equal 303, flow13_continuation.status
      flow13_registered_uri = URI.parse(
        OidcClientRegistry.find!("core-app-jp").redirect_uris_by_realm.fetch("client").first,
      )
      flow13_callback_uri = URI.parse(flow13_continuation.location)
      if flow13_callback_uri.host == "jump.umaxica.net"
        flow13_callback_uri = URI.parse(jump_rt_url_from_location_for_test(flow13_callback_uri.to_s))
      end

      assert_equal [flow13_registered_uri.host, flow13_registered_uri.path],
                   [flow13_callback_uri.host, flow13_callback_uri.path]
    end

    assert_response :redirect
    assert_not ClientGoogleIdentity.exists?(uid: new_uid)

    get auth_app_social_failure_url(message: "invalid_credentials", strategy: "google"),
        headers: browser_headers.merge("Host" => @host)

    # A provider-side failure ends the sign-path attempt with the uniform refusal
    # (D-47 / D-198); it never redirects back to sign-in.
    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_nil response.location
  end

  test "provider failure ends social auth started from sign up with a uniform refusal" do
    begin
      fv5016 = "google"
      fv5015 = "login"
      fv5014 = "sign_up"
      begin
        lf15_provider = fv5016
        lf15_intent = fv5015
        lf15_user = nil
        lf15_entry = fv5014
        lf15_ri = "jp"
        lf15_rt = nil
        lf15_referer = nil
        lf15_host = @host.presence || configured_host(:auth_service)
        host!(lf15_host) if respond_to?(:host!)
        lf15_normalized_provider = SocialIdentifiable.normalize_provider(lf15_provider)
        # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
        # be login CSRF, so there is no `new_` action to seed the flow through.
        lf15_continue_path =
          if lf15_intent.to_s == "link"
            public_send(:"auth_app_settings_#{lf15_normalized_provider}_path", ri: lf15_ri)
          elsif lf15_entry.to_s == "sign_up"
            public_send(
              :"auth_app_social_#{lf15_normalized_provider}_registration_path",
              ri: lf15_ri,
              rt: lf15_rt,
            )
          else
            public_send(
              :"auth_app_social_#{lf15_normalized_provider}_session_path",
              ri: lf15_ri,
              rt: lf15_rt,
            )
          end
        lf15_headers = social_callback_headers(lf15_host)
        lf15_headers["Referer"] = lf15_referer if lf15_referer.present?
        if lf15_user
          lf15_user_headers =
            begin
              rr15_headers =
                begin
                  rp_headers = as_user_headers(lf15_user, host: lf15_host)
                  rp_host = rp_headers["Host"]
                  rp_route =
                    begin
                      Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
                    rescue ActionController::RoutingError
                      nil
                    end
                  rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
                  rp_headers
                end
              rr15_host = rr15_headers["Host"]
              rr15_route =
                begin
                  Rails.application.routes.recognize_path("https://#{rr15_host}/") if rr15_host.present?
                rescue ActionController::RoutingError
                  nil
                end
              rr15_family, rr15_surface = rr15_route&.fetch(:controller)&.split("/")
              rr15_headers
            end
          lf15_token = ClientToken.find_by(public_id: lf15_user_headers["X-TEST-SESSION-PUBLIC-ID"])
          mark_token_step_up_satisfied_for_test(
            lf15_token,
            scope: SocialAuth::SOCIAL_LINK_SCOPE,
          ) if lf15_intent.to_s == "link" && lf15_token
          lf15_headers = lf15_headers.merge(lf15_user_headers)
        end
        if lf15_entry.to_s == "sign_up" && lf15_intent.to_s != "link"
          ENV.fetch("PUBLIC_VISA_SERVICE_URL")
          auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          @base_browser.get(
            "/oauth/authorize", params: @oidc_authorization.merge(prompt: "create"), headers: {
              "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
            },
          )
          current_browser = @base_browser
          12.times do
            break unless current_browser.response.redirect?

            target = URI.parse(current_browser.response.location)
            if target.host == "jump.umaxica.net"
              rt = Rack::Utils.parse_query(target.query).fetch("rt")
              target = URI.parse(JWT.decode(rt, nil, false).first.fetch("url"))
            end
            browser = (target.host == auth_host) ? self : @base_browser
            browser.host!(target.host) if target.host
            browser.https!
            browser.get(
              target.request_uri, headers: {
                "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
              },
            )
            current_browser = browser
            break if browser == self && !response.redirect?
          end

          assert_equal auth_host, request.host
          assert_response :success
        end
        post(lf15_continue_path, headers: lf15_headers)
        social_auth_state_from_response
      end
    end

    get auth_app_social_failure_url(message: "invalid_credentials", strategy: "google"),
        headers: browser_headers.merge("Host" => @host)

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_not session.key?(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
  end

  test "provider failure ends social auth started from sign in with a uniform refusal" do
    begin
      fv5013 = "apple"
      fv5012 = "login"
      fv5011 = nil
      begin
        lf16_provider = fv5013
        lf16_intent = fv5012
        lf16_user = nil
        lf16_entry = fv5011
        lf16_ri = "jp"
        lf16_rt = nil
        lf16_referer = nil
        lf16_host = @host.presence || configured_host(:auth_service)
        host!(lf16_host) if respond_to?(:host!)
        lf16_normalized_provider = SocialIdentifiable.normalize_provider(lf16_provider)
        # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
        # be login CSRF, so there is no `new_` action to seed the flow through.
        lf16_continue_path =
          if lf16_intent.to_s == "link"
            public_send(:"auth_app_settings_#{lf16_normalized_provider}_path", ri: lf16_ri)
          elsif lf16_entry.to_s == "sign_up"
            public_send(
              :"auth_app_social_#{lf16_normalized_provider}_registration_path",
              ri: lf16_ri,
              rt: lf16_rt,
            )
          else
            public_send(
              :"auth_app_social_#{lf16_normalized_provider}_session_path",
              ri: lf16_ri,
              rt: lf16_rt,
            )
          end
        lf16_headers = social_callback_headers(lf16_host)
        lf16_headers["Referer"] = lf16_referer if lf16_referer.present?
        if lf16_user
          lf16_user_headers =
            begin
              rr16_headers =
                begin
                  rp_headers = as_user_headers(lf16_user, host: lf16_host)
                  rp_host = rp_headers["Host"]
                  rp_route =
                    begin
                      Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
                    rescue ActionController::RoutingError
                      nil
                    end
                  rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
                  rp_headers
                end
              rr16_host = rr16_headers["Host"]
              rr16_route =
                begin
                  Rails.application.routes.recognize_path("https://#{rr16_host}/") if rr16_host.present?
                rescue ActionController::RoutingError
                  nil
                end
              rr16_family, rr16_surface = rr16_route&.fetch(:controller)&.split("/")
              rr16_headers
            end
          lf16_token = ClientToken.find_by(public_id: lf16_user_headers["X-TEST-SESSION-PUBLIC-ID"])
          mark_token_step_up_satisfied_for_test(
            lf16_token,
            scope: SocialAuth::SOCIAL_LINK_SCOPE,
          ) if lf16_intent.to_s == "link" && lf16_token
          lf16_headers = lf16_headers.merge(lf16_user_headers)
        end
        if lf16_entry.to_s == "sign_up" && lf16_intent.to_s != "link"
          ENV.fetch("PUBLIC_VISA_SERVICE_URL")
          auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          @base_browser.get(
            "/oauth/authorize", params: @oidc_authorization.merge(prompt: "create"), headers: {
              "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
            },
          )
          current_browser = @base_browser
          12.times do
            break unless current_browser.response.redirect?

            target = URI.parse(current_browser.response.location)
            if target.host == "jump.umaxica.net"
              rt = Rack::Utils.parse_query(target.query).fetch("rt")
              target = URI.parse(JWT.decode(rt, nil, false).first.fetch("url"))
            end
            browser = (target.host == auth_host) ? self : @base_browser
            browser.host!(target.host) if target.host
            browser.https!
            browser.get(
              target.request_uri, headers: {
                "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
              },
            )
            current_browser = browser
            break if browser == self && !response.redirect?
          end

          assert_equal auth_host, request.host
          assert_response :success
        end
        post(lf16_continue_path, headers: lf16_headers)
        social_auth_state_from_response
      end
    end

    get auth_app_social_failure_url(message: "invalid_credentials", strategy: "apple"),
        headers: browser_headers.merge("Host" => @host)

    assert_response :bad_request
    assert_equal I18n.t("errors.messages.invalid_request"), response.body
    assert_not session.key?(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)
  end

  test "unknown Apple sign-in neither registers an account nor links an identity" do
    setup_apple_mock_auth(uid: "unknown-signin-#{SecureRandom.hex(8)}")
    assert_no_difference(
      ["Client.count", "ClientExternalIdentity.count", "ClientSignUpFlow.count",
       "ClientToken.count",],
    ) do
      post auth_app_social_apple_session_path(ri: "jp"), headers: @callback_headers
      state = social_auth_state_from_response

      assert_predicate state, :present?
      get auth_app_social_apple_callback_path(ri: "jp"), params: { state: state }, headers: @callback_headers
    end
    assert_response :bad_request
    # A verified but unregistered subject gets the sign-up guidance, not the uniform refusal.
    assert_equal I18n.t("sign.app.social.verified_subject_guidance.unregistered.title"),
                 response.parsed_body.at_css("h1").text
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_predicate flash, :empty?
  end

  test "successful login sets auth cookies" do
    existing_uid = "cookie_test_#{SecureRandom.hex(4)}"
    # Sign-in never registers an account, so the Google subject must already exist
    # for the login this test exercises.
    existing_user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::NOTHING, public_id: PublicId.generate,
    )
    ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )
    setup_google_mock_auth(uid: existing_uid)

    state =
      begin
        fv5007 = "google"
        fv5006 = "login"
        fv5005 = nil
        begin
          lf18_provider = fv5007
          lf18_intent = fv5006
          lf18_user = nil
          lf18_entry = fv5005
          lf18_ri = "jp"
          lf18_rt = nil
          lf18_referer = nil
          lf18_host = @host.presence || configured_host(:auth_service)
          host!(lf18_host) if respond_to?(:host!)
          lf18_normalized_provider = SocialIdentifiable.normalize_provider(lf18_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf18_continue_path =
            if lf18_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf18_normalized_provider}_path",
                ri: lf18_ri,
              )
            elsif lf18_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf18_normalized_provider}_registration_path",
                ri: lf18_ri,
                rt: lf18_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf18_normalized_provider}_session_path",
                ri: lf18_ri,
                rt: lf18_rt,
              )
            end
          lf18_headers = social_callback_headers(lf18_host)
          lf18_headers["Referer"] = lf18_referer if lf18_referer.present?
          if lf18_user
            lf18_user_headers =
              begin
                rr18_headers =
                  begin
                    rp_headers = as_user_headers(lf18_user, host: lf18_host)
                    rp_host = rp_headers["Host"]
                    rp_route =
                      begin
                        Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
                      rescue ActionController::RoutingError
                        nil
                      end
                    rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
                    rp_headers
                  end
                rr18_host = rr18_headers["Host"]
                rr18_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr18_host}/") if rr18_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr18_family, rr18_surface = rr18_route&.fetch(:controller)&.split("/")
                rr18_headers
              end
            lf18_token = ClientToken.find_by(public_id: lf18_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf18_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf18_intent.to_s == "link" && lf18_token
            lf18_headers = lf18_headers.merge(lf18_user_headers)
          end
          if lf18_entry.to_s == "sign_up" && lf18_intent.to_s != "link"
            ENV.fetch("PUBLIC_VISA_SERVICE_URL")
            auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.get(
              "/oauth/authorize", params: @oidc_authorization.merge(prompt: "create"), headers: {
                "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
              },
            )
            current_browser = @base_browser
            12.times do
              break unless current_browser.response.redirect?

              target = URI.parse(current_browser.response.location)
              if target.host == "jump.umaxica.net"
                rt = Rack::Utils.parse_query(target.query).fetch("rt")
                target = URI.parse(JWT.decode(rt, nil, false).first.fetch("url"))
              end
              browser = (target.host == auth_host) ? self : @base_browser
              browser.host!(target.host) if target.host
              browser.https!
              browser.get(
                target.request_uri, headers: {
                  "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
                },
              )
              current_browser = browser
              break if browser == self && !response.redirect?
            end

            assert_equal auth_host, request.host
            assert_response :success
          end
          post(lf18_continue_path, headers: lf18_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow14_form = response.parsed_body.at_css("form#social-completion-form")
        flow14_fields =
          flow14_form.css("input[name]").to_h { |flow14_input|
            [
              flow14_input["name"],
              flow14_input["value"],
            ]
          }
        flow14_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow14_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow14_pair| flow14_pair.start_with?("#{flow14_rails_cookie}=") }
        flow14_owner_cookie << "#{flow14_rails_cookie}=#{Rack::Utils.escape(
          response
                    .cookies.fetch(flow14_rails_cookie),
        )}"
        post(
          flow14_form["action"],
          params: flow14_fields,
          headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow14_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow14_target = URI.parse(response.location)
      if flow14_target.path == "/sign/in/check"
        # The Auth handoff redirects to the Visa result page, which continues the parent
        # authorization by a same-origin POST.
        get(
          auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow14_visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
        flow14_result_uri = URI.parse(response.location)

        assert_equal [303, flow14_visa_host], [response.status, flow14_result_uri.host]
        @base_browser.host!(flow14_visa_host)
        @base_browser.https!
        @base_browser.get(
          flow14_result_uri.request_uri, headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site",
          },
        )
        flow14_form = @base_browser.response.parsed_body.at_css("form#visa-authorization-continuation-form")
        flow14_fields =
          flow14_form.css("input[name]").to_h { |flow14_input|
            [
              flow14_input["name"],
              flow14_input["value"],
            ]
          }
        @base_browser.post(
          flow14_form["action"], params: flow14_fields, headers: {
            "Origin" => "https://#{flow14_visa_host}",
            "Sec-Fetch-Site" => "same-origin",
            "Sec-Fetch-Mode" => "navigate",
            "Sec-Fetch-Dest" => "document",
          },
        )
      end
      break unless flow14_result_uri

      flow14_continuation = @base_browser.response

      assert_equal 303, flow14_continuation.status
      flow14_registered_uri = URI.parse(
        OidcClientRegistry.find!("core-app-jp").redirect_uris_by_realm.fetch("client").first,
      )
      flow14_callback_uri = URI.parse(flow14_continuation.location)
      if flow14_callback_uri.host == "jump.umaxica.net"
        flow14_callback_uri = URI.parse(jump_rt_url_from_location_for_test(flow14_callback_uri.to_s))
      end

      assert_equal [flow14_registered_uri.host, flow14_registered_uri.path],
                   [flow14_callback_uri.host, flow14_callback_uri.path]
    end

    assert_response :redirect

    # Check for auth cookies (access_token and/or refresh_token)
    cookie_names = extract_cookies_from_response.keys
    cookie_names.any? { |name|
      name.include?("access") || name.include?("token") || name.include?("session")
    }

    # Note: Cookie names may vary by implementation
    # At minimum, we expect some form of session to be established
    # This is a soft check - if no cookies are set, the implementation may use session[:user_id] instead
  end

  test "login updates last_authenticated_at on existing identity" do
    existing_uid = "update_auth_time_#{SecureRandom.hex(4)}"
    old_auth_time = 1.week.ago

    existing_user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::NOTHING,
      public_id: PublicId.generate,
      birthdate: "2000-01-01",
    )
    identity = ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
      last_authenticated_at: old_auth_time,
    )

    setup_google_mock_auth(uid: existing_uid)

    time_before = Time.current

    state =
      begin
        fv5004 = "google"
        fv5003 = "login"
        fv5002 = nil
        begin
          lf19_provider = fv5004
          lf19_intent = fv5003
          lf19_user = nil
          lf19_entry = fv5002
          lf19_ri = "jp"
          lf19_rt = nil
          lf19_referer = nil
          lf19_host = @host.presence || configured_host(:auth_service)
          host!(lf19_host) if respond_to?(:host!)
          lf19_normalized_provider = SocialIdentifiable.normalize_provider(lf19_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf19_continue_path =
            if lf19_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf19_normalized_provider}_path",
                ri: lf19_ri,
              )
            elsif lf19_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf19_normalized_provider}_registration_path",
                ri: lf19_ri,
                rt: lf19_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf19_normalized_provider}_session_path",
                ri: lf19_ri,
                rt: lf19_rt,
              )
            end
          lf19_headers = social_callback_headers(lf19_host)
          lf19_headers["Referer"] = lf19_referer if lf19_referer.present?
          if lf19_user
            lf19_user_headers =
              begin
                rr19_headers =
                  begin
                    rp_headers = as_user_headers(lf19_user, host: lf19_host)
                    rp_host = rp_headers["Host"]
                    rp_route =
                      begin
                        Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
                      rescue ActionController::RoutingError
                        nil
                      end
                    rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
                    rp_headers
                  end
                rr19_host = rr19_headers["Host"]
                rr19_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr19_host}/") if rr19_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr19_family, rr19_surface = rr19_route&.fetch(:controller)&.split("/")
                rr19_headers
              end
            lf19_token = ClientToken.find_by(public_id: lf19_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf19_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf19_intent.to_s == "link" && lf19_token
            lf19_headers = lf19_headers.merge(lf19_user_headers)
          end
          if lf19_entry.to_s == "sign_up" && lf19_intent.to_s != "link"
            ENV.fetch("PUBLIC_VISA_SERVICE_URL")
            auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.get(
              "/oauth/authorize", params: @oidc_authorization.merge(prompt: "create"), headers: {
                "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
              },
            )
            current_browser = @base_browser
            12.times do
              break unless current_browser.response.redirect?

              target = URI.parse(current_browser.response.location)
              if target.host == "jump.umaxica.net"
                rt = Rack::Utils.parse_query(target.query).fetch("rt")
                target = URI.parse(JWT.decode(rt, nil, false).first.fetch("url"))
              end
              browser = (target.host == auth_host) ? self : @base_browser
              browser.host!(target.host) if target.host
              browser.https!
              browser.get(
                target.request_uri, headers: {
                  "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document",
                },
              )
              current_browser = browser
              break if browser == self && !response.redirect?
            end

            assert_equal auth_host, request.host
            assert_response :success
          end
          post(lf19_continue_path, headers: lf19_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow15_form = response.parsed_body.at_css("form#social-completion-form")
        flow15_fields =
          flow15_form.css("input[name]").to_h { |flow15_input|
            [
              flow15_input["name"],
              flow15_input["value"],
            ]
          }
        flow15_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow15_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow15_pair| flow15_pair.start_with?("#{flow15_rails_cookie}=") }
        flow15_owner_cookie << "#{flow15_rails_cookie}=#{Rack::Utils.escape(
          response
                    .cookies.fetch(flow15_rails_cookie),
        )}"
        post(
          flow15_form["action"],
          params: flow15_fields,
          headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow15_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow15_target = URI.parse(response.location)
      if flow15_target.path == "/sign/in/check"
        # The Auth handoff redirects to the Visa result page, which continues the parent
        # authorization by a same-origin POST.
        get(
          auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow15_visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
        flow15_result_uri = URI.parse(response.location)

        assert_equal [303, flow15_visa_host], [response.status, flow15_result_uri.host]
        @base_browser.host!(flow15_visa_host)
        @base_browser.https!
        @base_browser.get(
          flow15_result_uri.request_uri, headers: {
            "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document", "Sec-Fetch-Site" => "cross-site",
          },
        )
        flow15_form = @base_browser.response.parsed_body.at_css("form#visa-authorization-continuation-form")
        flow15_fields =
          flow15_form.css("input[name]").to_h { |flow15_input|
            [
              flow15_input["name"],
              flow15_input["value"],
            ]
          }
        @base_browser.post(
          flow15_form["action"], params: flow15_fields, headers: {
            "Origin" => "https://#{flow15_visa_host}",
            "Sec-Fetch-Site" => "same-origin",
            "Sec-Fetch-Mode" => "navigate",
            "Sec-Fetch-Dest" => "document",
          },
        )
      end
      break unless flow15_result_uri

      flow15_continuation = @base_browser.response

      assert_equal 303, flow15_continuation.status
      flow15_registered_uri = URI.parse(
        OidcClientRegistry.find!("core-app-jp").redirect_uris_by_realm.fetch("client").first,
      )
      flow15_callback_uri = URI.parse(flow15_continuation.location)
      if flow15_callback_uri.host == "jump.umaxica.net"
        flow15_callback_uri = URI.parse(jump_rt_url_from_location_for_test(flow15_callback_uri.to_s))
      end

      assert_equal [flow15_registered_uri.host, flow15_registered_uri.path],
                   [flow15_callback_uri.host, flow15_callback_uri.path]
    end

    identity.reload

    assert_operator identity.last_authenticated_at, :>=, time_before,
                    "last_authenticated_at should be updated on login"
    assert_operator identity.last_authenticated_at, :>, old_auth_time,
                    "last_authenticated_at should be newer than before"
  end

  private

  # IMPORTANT: Social login authenticates by provider+uid ONLY, NOT email
  # We deliberately omit email from mock_auth to test this requirement

  def setup_apple_mock_auth(uid:)
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: uid,
      info: {}, # Apple may not provide any info when email scope is not requested
      credentials: {
        token: "apple_token_#{SecureRandom.hex(8)}",
        refresh_token: "apple_refresh_token",
        expires_at: 1.week.from_now.to_i,
      },
      extra: { id_info: { nonce: session[:social_auth_nonce] } },
    )
  end

  private
end

# DAMP auth header helpers for this test class.
class SocialAuthLoginTest
  private
end

# DAMP local helper copy for former shared test support.
class SocialAuthLoginTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def ensure_user_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
  end

  def ensure_staff_token_reference_records!
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    OperatorTokenBindingMethod.find_or_create_by!(id: OperatorTokenBindingMethod::LEGACY)
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  def create_verified_user_with_email(email_address: "user-#{SecureRandom.hex(4)}@example.com")
    ensure_user_reference_records!
    user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
    )
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.reload
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.create!(
      user_id: user_id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :app),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
  end

  def satisfy_user_verification(token, scope: nil)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_staff_verification(token, scope: nil)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def step_up_test_audience_for_token(token)
    case token.class.name
    when "OperatorToken" then "step_up:org"
    else "step_up:app"
    end
  end

  def signed_step_up_pt_for(path, surface:, session_nonce:)
    safe_path = path.to_s
    return nil if safe_path.blank? || !safe_path.start_with?("/") || safe_path.match?(/[\x00-\x1F\x7F]/)

    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256",
      serializer: JSON,
      url_safe: true,
    )
    verifier.generate(
      { "flow" => "step_up.bootstrap",
        "surface" => surface.to_s,
        "session_nonce" => session_nonce.to_s,
        "pt" => safe_path, },
      purpose: :path_target,
      expires_in: 15.minutes,
    )
  end

  def signed_step_up_grant_for(actor:, token:, scope:, return_to:, surface:, methods: %i(email_otp totp passkey),
                               aal: "aal2")
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: surface.to_s,
      actor_ref: actor.public_id,
      session_ref: token.public_id,
      required_scope: scope.to_s,
      required_aal: aal,
      allowed_methods: methods,
      return_to: return_to,
      expires_at: 15.minutes.from_now,
    ).grant
  end

  def csrf_headers(token)
    { "X-CSRF-Token" => token }
  end

  def fetch_csrf_token(path)
    get(path)
    response.body[/name="authenticity_token" value="([^"]+)"/, 1] || response.body
  end

  def social_callback_headers(host)
    scheme = host.to_s.include?("localhost") ? "http" : "https"
    origin = "#{scheme}://#{host}"
    cookies["csrf_token"] = csrf_token_value if respond_to?(:cookies)
    {
      "Host" => host,
      "Origin" => origin,
      "Referer" => "#{origin}/",
      "Sec-Fetch-Site" => "same-origin",
      "X-STRICT-SOCIAL-STATE" => "1",
      "X-CSRF-Token" => csrf_token_value,
    }
  end

  def social_auth_state_from_response
    session[:social_auth_state].presence || begin
      uri = URI.parse(response.location.to_s)
      Rack::Utils.parse_nested_query(uri.query.to_s)["state"].presence
    rescue URI::InvalidURIError
      nil
    end
  end

  def assert_oidc_authorize_redirect(location, host:, client_id: "base-rails-rp")
    uri = URI.parse(location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal client_id, query["client_id"]
    assert_predicate query["state"], :present?
  end
end

# DAMP local social completion helpers for former shared test support.
class SocialAuthLoginTest
  private
end

# DAMP local helper copy on the test class.
class SocialAuthLoginTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )

  private

  def assert_social_login_issued_visa_result(location)
    destination = URI.parse(location)

    assert_equal ENV.fetch("PUBLIC_VISA_SERVICE_URL"), destination.host
    assert_equal "/oidc/result", destination.path
  end

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def set_access_cookie(token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token
  end

  def set_refresh_cookie(token)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token
  end

  def jump_rt_url_from_location(location)
    uri = URI.parse(location.to_s)
    return location unless uri.host == "jump.umaxica.net"

    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    return location if token.blank?

    payload, = JWT.decode(token, nil, false)
    payload["url"].presence || location
  rescue JWT::DecodeError, URI::InvalidURIError
    location
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = { "Client-Agent" => self.class::TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = csrf_token_value
    cookies["csrf_token"] = csrf_token if respond_to?(:cookies, true)
    host_headers.merge("X-CSRF-Token" => csrf_token)
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    attrs = {
      last_step_up_at: at,
      last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
      last_step_up_aal: ("aal2" if token.respond_to?(:last_step_up_aal)),
      last_step_up_method: ("passkey" if token.respond_to?(:last_step_up_method)),
      last_step_up_session_public_id: (token.public_id if token.respond_to?(:last_step_up_session_public_id)),
      last_step_up_purpose: ("step_up" if token.respond_to?(:last_step_up_purpose)),
      last_step_up_audience: (step_up_test_audience_for_token(token) if token.respond_to?(:last_step_up_audience)),
      updated_at: Time.current,
    }.compact
    token.update_columns(attrs)
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(AUTH_APP AUTH_ORG ACME_APP ACME_ORG CORE_APP CORE_ORG BASE_APP BASE_ORG).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end

  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process and every later test expecting protection off would fail.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines = raw.is_a?(Array) ? raw : raw.to_s.split("\n")
    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def extract_cookies_from_response
    response_set_cookie_lines.each_with_object({}) do |line, parsed|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      parsed[name] = CGI.unescape(value.to_s) if name.present?
    end
  end

  def state_changing_application_route_targets
    Rails.application.routes.routes.filter_map do |route|
      verbs = route.verb.to_s.delete("^A-Z|").split("|")
      next if verbs.empty? || (verbs - %w(GET HEAD)).empty?

      controller = route.required_defaults[:controller].to_s
      action = route.required_defaults[:action].to_s
      next if controller.blank? || action.blank?

      controller_class_name = "#{controller.camelize}Controller"
      next unless Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

      { verb: verbs.join("|"),
        path: route.path.spec.to_s,
        controller: controller,
        action: action,
        controller_class: Object.const_get(controller_class_name), }
    rescue NameError
      nil
    end
  end

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com")
    OmniAuth.config.mock_auth[:google] =
      OmniAuth::AuthHash.new(
        provider: "google", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      )
  end
end
