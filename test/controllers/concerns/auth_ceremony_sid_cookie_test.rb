# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthCeremonySidCookieTest < ActionDispatch::IntegrationTest
  # This harness uses the shared application base without loading a surface-specific controller.
  class HarnessController < ApplicationController
    include AuthCeremonySidCookie

    def show
      render plain: read_auth_ceremony_sid_cookie.to_s
    end

    def create
      write_auth_ceremony_sid_cookie!(params[:sid])
      head :no_content
    end

    def destroy
      delete_auth_ceremony_sid_cookie!
      head :no_content
    end
  end

  test "cookie helper exposes host-prefixed random-only name in secure context" do
    assert_equal "auth_sid", AuthCeremonySidCookie::COOKIE_BASENAME
    source = Rails.root.join("app/controllers/concerns/auth_ceremony_sid_cookie.rb").read

    assert_match(/secure: JitSessionCookieConfig\.force_secure\?/, source)
    assert_match(/httponly: true/, source)
    assert_match(/HOST_COOKIE_PREFIX/, source)
    body = source.split("module AuthCeremonySidCookie", 2).last

    assert_no_match(/access_token|id_token|aal\b/i, body)
  end

  test "secure cookie helpers write read and delete only the opaque ceremony sid" do
    with_routing do |set|
      set.draw do
        get "/auth_sid", to: "auth_ceremony_sid_cookie_test/harness#show"
        post "/auth_sid", to: "auth_ceremony_sid_cookie_test/harness#create"
        delete "/auth_sid", to: "auth_ceremony_sid_cookie_test/harness#destroy"
      end

      JitSessionCookieConfig.stub(:force_secure?, true) do
        https!
        get "/auth_sid"

        assert_response :success
        assert_equal "", response.body

        post "/auth_sid", params: { sid: "opaque-ceremony-sid" }

        assert_response :no_content
        cookie_header = response.headers["Set-Cookie"].to_s

        assert_includes cookie_header, "__Host-auth_sid=opaque-ceremony-sid"
        assert_includes cookie_header, "secure"
        assert_includes cookie_header, "httponly"
        assert_includes cookie_header, "path=/"
        assert_includes cookie_header.downcase, "samesite=lax"

        get "/auth_sid"

        assert_equal "opaque-ceremony-sid", response.body

        delete "/auth_sid"

        assert_response :no_content
        assert_includes response.headers["Set-Cookie"].to_s, "__Host-auth_sid=;"
        get "/auth_sid"

        assert_equal "", response.body
      end
    end
  end
end
