# frozen_string_literal: true

require "test_helper"
require "concurrent/executor/simple_executor_service"
require "timeout"

class AuthAdmissionActiveParentUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  test "handoff reuses its active browser binding and refuses a different browser" do
    [
      [ClientOidcAuthorizationTransaction, ClientAuthAdmissionBinding, "app", "core-app-jp"],
      [OperatorOidcAuthorizationTransaction, OperatorAuthAdmissionBinding, "org", "core-org-jp"],
    ].each do |oidc_model, binding_model, realm, client_id|
      now = oidc_model.database_now
      parent = oidc_model.create_transaction!(
        surface: realm, intent: "sign_in", client_id: client_id, redirect_uri: "https://example.com/callback",
        response_type: "code", scope: "openid", state: "state", nonce: "nonce",
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", code_challenge_method: "S256",
        login_challenge: SecureRandom.base58(32), login_challenge_expires_at: now + 15.minutes,
        expires_at: now + 15.minutes,
      )
      browser_nonce = SecureRandom.urlsafe_base64(32)
      first = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: parent, base_browser_nonce: browser_nonce, base_token: nil,
      )
      first_binding = binding_model.find_by!(entry_ref: first.reference)
      unchanged = first_binding.attributes
      again = BaseAuthAdmissionCoordinator.issue_handoff!(
        transaction: parent, base_browser_nonce: browser_nonce, base_token: nil,
      )

      assert_equal first.reference, again.reference
      assert_equal unchanged, first_binding.reload.attributes
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseAuthAdmissionCoordinator.issue_handoff!(
          transaction: parent, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
        )
      end
      assert_equal unchanged, first_binding.reload.attributes
      assert_equal 1, binding_model.where(authorization_transaction_id: parent.id).count
    end
  end

  [
    [ClientOidcAuthorizationTransaction, ClientStepUpCeremonyTransaction, ClientAuthAdmissionBinding, "app",
     "core-app-jp",],
    [OperatorOidcAuthorizationTransaction, OperatorStepUpCeremonyTransaction, OperatorAuthAdmissionBinding, "org",
     "core-org-jp",],
  ].each do |oidc_model, ticket_model, binding_model, realm, client_id|
    [:oidc, :step_up].each do |parent_kind|
      test "#{realm} #{parent_kind} has one active binding per purpose and permits retired history" do
        now = binding_model.database_now
        token = (realm == "app") ? client_tokens(:one) : operator_tokens(:one)
        parent =
          if parent_kind == :oidc
            oidc_model.create_transaction!(
              surface: realm, intent: "sign_in", client_id: client_id, redirect_uri: "https://example.com/callback",
              response_type: "code", scope: "openid", state: "state", nonce: "nonce",
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", code_challenge_method: "S256",
              login_challenge: SecureRandom.base58(32), login_challenge_expires_at: now + 15.minutes,
              expires_at: now + 15.minutes,
            )
          else
            ticket_model.create_transaction!(
              actor_ref: "historical-actor", session_ref: token.public_id, required_scope: "settings_passkey",
              required_aal: "none", allowed_methods: ["passkey"], purpose: "credential_registration",
              step_up_required: false,
            )
          end
        field = (parent_kind == :oidc) ? :authorization_transaction_id : :step_up_ceremony_transaction_id
        purpose = (parent_kind == :oidc) ? "authentication_handoff" : "credential_registration_handoff"
        intent = (parent_kind == :oidc) ? "sign_in" : "not_applicable"
        attributes = {
          :entry_ref => SecureRandom.uuid,
          :purpose => purpose,
          :entry_intent => intent,
          field => parent.id,
          :base_browser_digest => SecureRandom.hex(32),
          :expires_at => now + 15.minutes,
          :curfew_at => now + 15.minutes,
          :created_at => now,
          :updated_at => now,
        }
        attributes[:base_token_id] = token.id if parent_kind == :step_up
        existing = binding_model.create!(attributes)
        replacement_attributes = attributes.merge(entry_ref: SecureRandom.uuid)
        replacement = binding_model.new(replacement_attributes)

        assert_not replacement.valid?
        assert replacement.errors.of_kind?(field, :taken)
        [:en, :ja].each do |locale|
          I18n.with_locale(locale) { assert_raises(ActiveRecord::RecordInvalid) { replacement.save! } }
        end
        assert_raises(ActiveRecord::RecordNotUnique) do
          binding_model.transaction(requires_new: true) { binding_model.insert_all!([replacement_attributes]) }
        end
        other_purpose = (parent_kind == :oidc) ? "invitation_handoff" : "bootstrap_handoff"
        other = binding_model.create!(attributes.merge(entry_ref: SecureRandom.uuid, purpose: other_purpose))

        assert_predicate other, :active?
        existing.retire!
        replacement.save!

        assert_predicate existing.reload, :retired?
        assert_predicate replacement.reload, :active?
      end
    end
  end
end

class AuthAdmissionActiveParentUniquenessConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  [
    [ClientOidcAuthorizationTransaction, ClientStepUpCeremonyTransaction, ClientAuthAdmissionBinding, "app",
     "core-app-jp",],
    [OperatorOidcAuthorizationTransaction, OperatorStepUpCeremonyTransaction, OperatorAuthAdmissionBinding, "org",
     "core-org-jp",],
  ].each do |oidc_model, ticket_model, binding_model, realm, client_id|
    [:oidc, :step_up].each do |parent_kind|
      test "#{realm} #{parent_kind} simultaneous parent claims yield one database winner" do
        now = binding_model.database_now
        token = (realm == "app") ? client_tokens(:one) : operator_tokens(:one)
        parent =
          if parent_kind == :oidc
            oidc_model.create_transaction!(
              surface: realm, intent: "sign_in", client_id: client_id, redirect_uri: "https://example.com/callback",
              response_type: "code", scope: "openid", state: "state", nonce: "nonce",
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", code_challenge_method: "S256",
              login_challenge: SecureRandom.base58(32), login_challenge_expires_at: now + 15.minutes,
              expires_at: now + 15.minutes,
            )
          else
            ticket_model.create_transaction!(
              actor_ref: "historical-actor", session_ref: token.public_id, required_scope: "settings_passkey",
              required_aal: "none", allowed_methods: ["passkey"], purpose: "credential_registration",
              step_up_required: false,
            )
          end
        field = (parent_kind == :oidc) ? :authorization_transaction_id : :step_up_ceremony_transaction_id
        purpose = (parent_kind == :oidc) ? "authentication_handoff" : "credential_registration_handoff"
        intent = (parent_kind == :oidc) ? "sign_in" : "not_applicable"
        entry_refs = 2.times.map { SecureRandom.uuid }
        ready = Queue.new
        release = Queue.new
        workers =
          entry_refs.map do |entry_ref|
            Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
              binding_model.connection_pool.with_connection do |connection|
                ready << connection.select_value("SELECT pg_backend_pid()")
                release.pop
                attributes = {
                  :entry_ref => entry_ref,
                  :purpose => purpose,
                  :entry_intent => intent,
                  field => parent.id,
                  :base_browser_digest => "a" * 64,
                  :expires_at => now + 15.minutes,
                  :curfew_at => now + 15.minutes,
                  :created_at => now,
                  :updated_at => now,
                }
                attributes[:base_token_id] = token.id if parent_kind == :step_up
                binding_model.insert_all!([attributes])
                :created
              rescue ActiveRecord::RecordNotUnique
                :conflict
              end
            ensure
              ActiveRecord::Base.connection_handler.clear_active_connections!
            end
          end
        backends = Timeout.timeout(10) { 2.times.map { ready.pop } }
        2.times { release << true }
        outcomes = Timeout.timeout(10) { workers.map(&:value!) }

        assert_equal 2, backends.uniq.size
        assert_equal %i(conflict created), outcomes.sort
        assert_equal 1, binding_model.where(entry_ref: entry_refs).count
      ensure
        2.times { release << true } if release
        workers&.each { |worker| worker.wait(10) }
        binding_model.where(entry_ref: entry_refs).delete_all if entry_refs
        parent&.delete
      end
    end
  end
end
