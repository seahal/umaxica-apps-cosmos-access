# typed: false
# frozen_string_literal: true

require "test_helper"

class TargetedModelLineCoverageTest < ActiveSupport::TestCase
  class AbstractOidcAuthorization < ApplicationRecord
    self.abstract_class = true
    include OidcAuthorizationTransactionable
  end

  class AbstractStepUpCeremony < ApplicationRecord
    self.abstract_class = true
    include StepUpCeremonyTransactionable
  end

  test "session limit transaction predicates expose every state" do
    states = {
      ClientSessionLimitResolutionTransaction::PENDING => :pending?,
      ClientSessionLimitResolutionTransaction::SESSION_SELECTED => :session_selected?,
      ClientSessionLimitResolutionTransaction::RESOLVED => :resolved?,
      ClientSessionLimitResolutionTransaction::EXPIRED => :expired?,
      ClientSessionLimitResolutionTransaction::CANCELLED => :cancelled?,
    }

    states.each do |state, predicate|
      assert_predicate ClientSessionLimitResolutionTransaction.new(state_id: state), predicate
    end
  end

  test "session limit issuance fails closed without Governance authority" do
    assert_raises(GovernanceLookupUnavailableError) do
      ClientSessionLimitResolutionTransaction.issue!(
        sign_in_flow: nil,
        actor: nil,
        browser_binding_digest: nil,
      )
    end
  end

  test "sign-in flow delegates its remaining public transitions" do
    sign_in = ClientSignInFlow.new
    assert_raises(GovernanceLookupUnavailableError) { sign_in.advance_sign_in_to_selector! }
    discard_calls = []
    sign_in.stub(:discard_cycle!, ->(**options) { discard_calls << options }) do
      sign_in.discard_sign_in!(now: Time.current)
    end

    assert_equal sign_in.purge_eligible_at, discard_calls.last.fetch(:purge_eligible_at)
  end

  test "unknown oidc and step up stores use the base connection owner" do
    assert_equal ActiveRecord::Base, AbstractOidcAuthorization.connection_owner
    assert_equal ActiveRecord::Base, AbstractStepUpCeremony.connection_owner
  end

  test "logout transaction handles stale consumption and a disappearing lookup" do
    transaction = LogoutTransaction.new
    transaction.stub(:with_lock, -> { raise ActiveRecord::StaleObjectError }) do
      transaction.stub(:reload, transaction) do
        transaction.stub(:consumed?, true) do
          result = transaction.consume!(verifier: "verifier", issuer: "issuer", audience: "audience", purpose: "logout")

          assert_equal :consumed, result.status
        end
      end
    end

    LogoutTransaction.stub(:find_by, ->(**_attributes) { raise ActiveRecord::RecordNotFound }) do
      result = LogoutTransaction.consume_one_time_url_token!(
        raw_token: "public-id.verifier",
        issuer: "issuer",
        audience: "audience",
        purpose: "logout",
      )

      assert_equal :invalid, result.status
    end
  end

  test "unsupported email verification outcome is reported" do
    transaction = ClientEmailCeremonyTransaction.new(
      evp_outcome: "unsupported",
      evp_nonce_digest: "digest",
      evp_consumed_at: Time.current,
    )

    assert_not transaction.valid?
    assert_includes transaction.errors.details[:evp_outcome], { error: "is unsupported" }
  end
end
