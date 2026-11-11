# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceWriteBoundaryTest < ActiveSupport::TestCase
  REALM_MODELS = {
    app: AppPreference,
    org: OrgPreference,
  }.freeze

  test "accepts the closed operation set on the owning surface" do
    {
      "auth/app" => :app, "auth/org" => :org,
    }.each do |surface_key, realm|
      result = PreferenceWriteBoundary.authorize!(
        surface_key: surface_key, operation: :save, realm_model: REALM_MODELS.fetch(realm),
      )

      assert_equal realm, result[:realm]
      assert_equal :save, result[:operation]
    end
  end

  test "wires the Visa sign_in and sign_out operations for realms that own a Visa read" do
    result = PreferenceWriteBoundary.authorize!(
      surface_key: "visa/app", operation: :sign_in, realm_model: "AppPreference",
    )

    assert_equal [:app, :sign_in], result.values_at(:realm, :operation)

    result = PreferenceWriteBoundary.authorize!(
      surface_key: "visa/org", operation: :sign_out, realm_model: "OrgPreference",
    )

    assert_equal [:org, :sign_out], result.values_at(:realm, :operation)
  end

  test "refuses an operation outside the closed enumeration" do
    error =
      assert_raises(PreferenceWriteBoundary::UnsupportedOperationError) do
        PreferenceWriteBoundary.authorize!(
          surface_key: "auth/app", operation: :purge, realm_model: AppPreference,
        )
      end

    assert_match(/unsupported preference operation/, error.message)
  end

  test "refuses a Visa-only operation on Auth" do
    error =
      assert_raises(PreferenceWriteBoundary::UnsupportedOperationError) do
        PreferenceWriteBoundary.authorize!(
          surface_key: "auth/app", operation: :sign_in, realm_model: AppPreference,
        )
      end

    assert_match(/may not use operation :sign_in/, error.message)
  end

  test "refuses an unlisted surface entirely" do
    error =
      assert_raises(PreferenceWriteBoundary::UnsupportedSurfaceError) do
        PreferenceWriteBoundary.authorize!(
          surface_key: "retired/org", operation: :save, realm_model: OrgPreference,
        )
      end

    assert_equal "retired/org", error.message
  end

  test "refuses a surface that names another realm's model class" do
    error =
      assert_raises(PreferenceWriteBoundary::UnsupportedSurfaceError) do
        PreferenceWriteBoundary.authorize!(
          surface_key: "auth/app", operation: :save, realm_model: OrgPreference,
        )
      end

    assert_match(/may not write/, error.message)
  end

  test "refuses a lookalike model name and a missing model" do
    ["Other::Preference", "PreferencePreference", "", nil].each do |model|
      assert_raises(PreferenceWriteBoundary::UnsupportedSurfaceError) do
        PreferenceWriteBoundary.authorize!(surface_key: "auth/app", operation: :save, realm_model: model)
      end
    end
  end

  test "static Visa writer authorization is limited to verified results and committed logout confirmations" do
    {
      ["visa/app", :sign_in, AppPreference] => Visa::App::Oauth::AuthorizationsController,
      ["visa/app", :sign_out, AppPreference] => Visa::App::Oidc::Logouts::ConfirmationsController,
      ["visa/org", :sign_in, OrgPreference] => Visa::Org::Oauth::AuthorizationsController,
      ["visa/org", :sign_out, OrgPreference] => Visa::Org::Oidc::Logouts::ConfirmationsController,
    }.each do |(surface_key, operation, realm_model), controller|
      result = PreferenceWriteBoundary.authorize_writer!(
        controller:, action: "create", surface_key:, operation:, realm_model:,
      )

      expected_realm = (realm_model == AppPreference) ? :app : :org

      assert_equal [expected_realm, operation], result.values_at(:realm, :operation)
    end

    assert_raises(PreferenceWriteBoundary::UnsupportedSurfaceError) do
      PreferenceWriteBoundary.authorize_writer!(
        controller: Visa::App::Oauth::AuthorizationsController, action: "show", surface_key: "visa/app",
        operation: :sign_in, realm_model: AppPreference,
      )
    end

    assert_raises(PreferenceWriteBoundary::UnsupportedSurfaceError) do
      PreferenceWriteBoundary.authorize_writer!(
        controller: Visa::App::Oidc::LogoutsController, action: "create", surface_key: "visa/app",
        operation: :sign_out, realm_model: AppPreference,
      )
    end
  end

  test "static writer authorization refuses cross-realm and non-preference callers" do
    assert_raises(PreferenceWriteBoundary::UnsupportedSurfaceError) do
      PreferenceWriteBoundary.authorize_writer!(
        controller: Auth::App::Api::V0::Preferences::CookiesController, action: "update", surface_key: "auth/org",
        operation: :save, realm_model: OrgPreference,
      )
    end

    assert_raises(PreferenceWriteBoundary::UnsupportedSurfaceError) do
      PreferenceWriteBoundary.authorize_writer!(
        controller: Auth::App::ApplicationController, action: "update", surface_key: "auth/app",
        operation: :save, realm_model: AppPreference,
      )
    end

    assert_raises(PreferenceWriteBoundary::UnsupportedOperationError) do
      PreferenceWriteBoundary.authorize_writer!(
        controller: Auth::App::Api::V0::Preferences::CookiesController, action: "update", surface_key: "auth/app",
        operation: :sign_in, realm_model: AppPreference,
      )
    end
  end
end
