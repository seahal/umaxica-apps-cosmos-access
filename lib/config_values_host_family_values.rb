# frozen_string_literal: true

module ConfigValues
  HostFamilyValues =
    Data.define(:auth_service, :auth_staff, :visa_service, :visa_staff) do
      def auth_origins = [auth_service, auth_staff]

      def visa_origins = [visa_service, visa_staff]
    end
end

ConfigValuesHostFamilyValues = ConfigValues::HostFamilyValues

class << ConfigValues::HostFamilyValues
  def build(env:, production:)
    ConfigValues::HostFamilyValues.new(
      auth_service: origin(env, "PUBLIC_AUTH_SERVICE_URL", production:),
      auth_staff: origin(env, "PUBLIC_AUTH_STAFF_URL", production:),
      visa_service: origin(env, "PUBLIC_VISA_SERVICE_URL", production:),
      visa_staff: origin(env, "PUBLIC_VISA_STAFF_URL", production:),
    ).freeze
  end

  private

  def origin(env, key, production:)
    raw = env.fetch(key)
    uri = raw.match?(%r{\Ahttps?://}) ? raw : "https://#{raw}"
    ConfigValues.build(uri, allow_localhost: !production)
  rescue KeyError
    raise KeyError, "Missing required ENV key: #{key}"
  end
end
