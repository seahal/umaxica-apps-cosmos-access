# typed: false
# frozen_string_literal: true

require "test_helper"

class JitSecurityTurnstileConfigTest < ActiveSupport::TestCase
  test "stealth keys resolve through their distinct credential names" do
    configured = {
      CLOUDFLARE_TURNSTILE_SITE_STEALTH_KEY: "stealth-site-key",
      CLOUDFLARE_TURNSTILE_SECRET_STEALTH_KEY: "stealth-secret-key",
    }
    option = ->(key, **) { configured.fetch(key) }

    Rails.app.creds.stub(:option, option) do
      assert_equal "stealth-site-key", JitSecurityTurnstileConfig.stealth_site_key
      assert_equal "stealth-secret-key", JitSecurityTurnstileConfig.stealth_secret_key
    end
  end
end
