# typed: false
# frozen_string_literal: true

# Runtime kill switch for outbound delivery channels that depend on a third party
# (Amazon SNS for SMS, the SMTP relay for email).
#
# Polarity is deliberate and the opposite of
# ExternalAuthentication::FlipperProviderAvailabilityAdapter: the feature names a
# *suspension*, so an unset or unknown feature means "not suspended" and delivery runs
# normally. A flag store that has never been written must not take the product's OTP
# delivery down, whereas an operator enabling the flag during a provider incident must
# stop delivery immediately. The authentication adapter faces the opposite risk (a lost
# flag must not let a ceremony through) and therefore reads unset as disabled.
class OutboundChannelSuspension
  CHANNEL_FEATURE_NAMES = {
    sms: :outbound_sms_suspended,
    email: :outbound_email_suspended,
  }.freeze

  def self.suspended?(channel, flipper: Flipper)
    new(flipper: flipper).suspended?(channel)
  end

  def initialize(flipper: Flipper)
    @flipper = flipper
  end

  def suspended?(channel)
    feature_name =
      CHANNEL_FEATURE_NAMES.fetch(channel.to_sym) do
        raise ArgumentError, "unsupported outbound channel: #{channel}"
      end

    FeatureFlags.enabled?(feature_name, flipper: @flipper)
  end
end
