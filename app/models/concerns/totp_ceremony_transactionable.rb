# typed: false
# frozen_string_literal: true

module TotpCeremonyTransactionable
  extend ActiveSupport::Concern

  DEFAULT_TTL = 10.minutes
  STATUS_PENDING = "pending"
  STATUS_CONSUMED = "consumed"
  STATUSES = [STATUS_PENDING, STATUS_CONSUMED].freeze
  RETENTION_PERIOD = 7.days

  class_methods do
    def ceremony_surface(value = nil)
      raise ArgumentError, "ceremony surface must be declared" if value.nil?

      declared_surface = value.to_s.dup.freeze
      define_singleton_method(:ceremony_surface) { declared_surface }
      declared_surface
    end

    def create_transaction!(surface: ceremony_surface, actor_ref:, session_ref:, operation:, transaction_id: nil,
                            grant_jti: nil, credential_candidate_ref: nil, credential_candidate_digest: nil,
                            step_up_ceremony_transaction_ref: nil, expires_at: nil, now: Time.current)
      transaction_id = transaction_id.presence
      grant_jti = grant_jti.presence
      generated_attributes = []
      generated_attributes << :transaction_id if transaction_id.nil?
      generated_attributes << :grant_jti if grant_jti.nil?
      retries = 0

      connection_owner.connected_to(role: :writing) do
        loop do
          generated_transaction_id = transaction_id || PublicId.generate
          generated_grant_jti = grant_jti || PublicId.generate
          attributes = {
            transaction_id: generated_transaction_id,
            surface: surface.to_s,
            actor_ref: actor_ref,
            session_ref: session_ref,
            operation: operation,
            grant_jti: generated_grant_jti,
            credential_candidate_ref: credential_candidate_ref,
            credential_candidate_digest: credential_candidate_digest,
            step_up_ceremony_transaction_ref: step_up_ceremony_transaction_ref,
            expires_at: expires_at || (now + DEFAULT_TTL),
            created_at: now,
            updated_at: now,
          }

          begin
            return transaction(requires_new: true) { create!(attributes) }
          rescue ActiveRecord::RecordInvalid => e
            raise unless generated_reference_collision_validation?(e, generated_attributes)
          rescue ActiveRecord::RecordNotUnique => e
            raise unless generated_reference_collision?(e, generated_attributes)
          end

          retries += 1
          raise if retries > PublicId::MAX_COLLISION_RETRIES
        end
      end
    end

    def connection_owner
      if self <= OpBaseAppRecord
        OpBaseAppRecord
      else
        ActiveRecord::Base
      end
    end

    private

    def generated_reference_collision_validation?(error, generated_attributes)
      generated_attributes.any? { |attribute| error.record.errors.of_kind?(attribute, :taken) }
    end

    def generated_reference_collision?(error, generated_attributes)
      result = error.cause&.result
      return false unless result

      constraint = result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      lease_connection.schema_cache.indexes(table_name).any? do |index|
        index.name == constraint && index.unique && index.where.nil? && index.columns.one? &&
          generated_attributes.include?(index.columns.first.to_sym)
      end
    end
  end

  public

  def grant_claims(now: Time.current)
    {
      "surface" => surface,
      "actor_ref" => actor_ref,
      "session_ref" => session_ref,
      "transaction_id" => transaction_id,
      "jti" => grant_jti,
      "operation" => operation,
      "credential_candidate_ref" => credential_candidate_ref,
      "credential_candidate_digest" => credential_candidate_digest,
      "exp" => expires_at.to_i,
      "iat" => now.to_i,
    }.compact
  end

  def expired?(now: Time.current)
    expires_at.to_i <= now.to_i
  end

  def consumed? = status == STATUS_CONSUMED

  def consume_result!(result_jti:, consumed_at: Time.current)
    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find(id)
        raise IdentityTotpCeremonyContract::Error, "transaction is already consumed" if locked.consumed?
        raise IdentityTotpCeremonyContract::Error, "transaction is expired" if locked.expired?(now: consumed_at)

        locked.update!(result_jti: result_jti, consumed_at: consumed_at, status: STATUS_CONSUMED)
        locked
      end
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
    raise IdentityTotpCeremonyContract::Error, "result_jti has already been consumed: #{e.message}"
  end

  private

  def surface_matches_transaction_class
    return if self.class.ceremony_surface.blank? || surface == self.class.ceremony_surface

    errors.add(:surface, "does not match transaction store")
  end

  def consumed_transaction_has_result
    return unless status == STATUS_CONSUMED && result_jti.blank?

    errors.add(:result_jti, "is required for consumed transaction")
  end
end
