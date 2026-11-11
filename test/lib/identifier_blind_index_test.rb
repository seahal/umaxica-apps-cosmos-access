# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentifierBlindIndexTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "blank email and telephone identifiers do not acquire lookup digests" do
    %w(app org).each do |realm|
      [nil, "", "   "].each do |identifier|
        assert_nil IdentifierBlindIndex.bidx_for_email(identifier, realm:)
        assert_nil IdentifierBlindIndex.bidx_for_telephone(identifier, realm:)
      end
    end
  end

  %w(app org).each do |realm|
    %w(email telephone).each do |channel|
      test "#{realm} #{channel} lookup uses only its credential even with a conflicting environment key" do
        key =
          case channel
          when "email" then :"#{realm.upcase}_EMAIL_ADDRESS_HMAC_KEY"
          when "telephone" then :"#{realm.upcase}_TELEPHONE_NUMBER_HMAC_KEY"
          end
        saved = ENV[key.to_s]
        ENV[key.to_s] = "conflicting-environment-key"
        credential = "controlled-#{realm}-#{channel}-credential"
        lookup = ->(name) { (name == key) ? credential : nil }

        Rails.application.credentials.stub(:option, lookup) do
          first, second, normalized =
            case channel
            when "email"
              [IdentifierBlindIndex.bidx_for_email("user@example.com", realm:),
               IdentifierBlindIndex.bidx_for_email("  USER@Example.COM  ", realm:), "user@example.com",]
            when "telephone"
              [IdentifierBlindIndex.bidx_for_telephone("+819012345678", realm:),
               IdentifierBlindIndex.bidx_for_telephone("090-1234-5678", realm:), "+819012345678",]
            end
          expected = OpenSSL::HMAC.hexdigest("SHA256", credential, "#{realm}:#{channel}:#{normalized}")

          assert_withheld("Lookup must use the credential, not the conflicting environment value") { first == expected }
          assert_withheld("Equivalent identifiers must have the same lookup digest") { first == second }
        end
      ensure
        if saved.nil?
          ENV.delete(key.to_s)
        else
          ENV[key.to_s] = saved
        end
      end

      test "#{realm} #{channel} missing empty and whitespace credentials fail even with an environment key" do
        key =
          case channel
          when "email" then :"#{realm.upcase}_EMAIL_ADDRESS_HMAC_KEY"
          when "telephone" then :"#{realm.upcase}_TELEPHONE_NUMBER_HMAC_KEY"
          end
        saved = ENV[key.to_s]
        ENV[key.to_s] = "environment-key-must-not-be-a-fallback"

        [nil, "", " \t"].each do |credential|
          Rails.application.credentials.stub(:option, credential) do
            error =
              assert_raises(KeyError) do
                case channel
                when "email" then IdentifierBlindIndex.bidx_for_email("user@example.com", realm:)
                when "telephone" then IdentifierBlindIndex.bidx_for_telephone("+819012345678", realm:)
                end
              end

            assert_equal "Missing key: [:#{key}]", error.message
          end
        end
      ensure
        if saved.nil?
          ENV.delete(key.to_s)
        else
          ENV[key.to_s] = saved
        end
      end
    end
  end
end
