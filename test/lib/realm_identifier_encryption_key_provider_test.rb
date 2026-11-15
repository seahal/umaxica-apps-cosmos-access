# frozen_string_literal: true

require "test_helper"

class RealmIdentifierEncryptionKeyProviderTest < ActiveSupport::TestCase
  APP_KEYS = RealmIdentifierEncryptionKeyProvider::KEYS.fetch("app").freeze

  test "the active key encrypts new values and the previous key still decrypts existing values" do
    current_name, previous_name, salt_name = APP_KEYS
    original_current = ENV[current_name]
    original_previous = ENV[previous_name]
    original_salt = ENV[salt_name]

    begin
      ENV[current_name] = "previous-app-encryption-key"
      ENV.delete(previous_name)
      ENV[salt_name] = "app-encryption-salt"
      previous_key = RealmIdentifierEncryptionKeyProvider.key_provider(realm: "app").encryption_key
      previous_only = ActiveRecord::Encryption::KeyProvider.new([previous_key])

      ENV[current_name] = "active-app-encryption-key"
      ENV[previous_name] = ["previous-app-encryption-key"].to_json
      provider = RealmIdentifierEncryptionKeyProvider.key_provider(realm: "app")
      encryptor = ActiveRecord::Encryption::Encryptor.new
      old_ciphertext = encryptor.encrypt("legacy identifier", key_provider: previous_only)
      current_ciphertext = encryptor.encrypt("current identifier", key_provider: provider)

      assert_equal "legacy identifier", encryptor.decrypt(old_ciphertext, key_provider: provider)
      assert_equal "current identifier", encryptor.decrypt(current_ciphertext, key_provider: provider)
      assert_equal 32, provider.encryption_key.secret.bytesize
    ensure
      ENV[current_name] = original_current
      original_previous.nil? ? ENV.delete(previous_name) : ENV[previous_name] = original_previous
      original_salt.nil? ? ENV.delete(salt_name) : ENV[salt_name] = original_salt
    end
  end

  test "invalid realms and malformed or blank configured keys fail explicitly" do
    assert_raises(KeyError) { RealmIdentifierEncryptionKeyProvider.key_provider(realm: "unknown") }

    current_name, previous_name, salt_name = APP_KEYS
    original_current = ENV[current_name]
    original_previous = ENV[previous_name]
    original_salt = ENV[salt_name]

    begin
      ENV[current_name] = ""
      ENV.delete(previous_name)
      ENV[salt_name] = "app-encryption-salt"
      assert_raises(ArgumentError) { RealmIdentifierEncryptionKeyProvider.key_provider(realm: "app") }

      ENV[current_name] = "active-app-encryption-key"
      ENV[previous_name] = "["
      ENV[salt_name] = "salt"
      assert_raises(ArgumentError) { RealmIdentifierEncryptionKeyProvider.key_provider(realm: "app") }
    ensure
      ENV[current_name] = original_current
      original_previous.nil? ? ENV.delete(previous_name) : ENV[previous_name] = original_previous
      original_salt.nil? ? ENV.delete(salt_name) : ENV[salt_name] = original_salt
    end
  end
end
