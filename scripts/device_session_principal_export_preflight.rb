# frozen_string_literal: true

# A bounded, pre-retirement check. Call only with the actual old actor/root models;
# their authentication predicates remain the authority for this export operation.
class DeviceSessionPrincipalExportPreflight
  class Refused < StandardError; end

  class << self
    def call(realm:, roots:, devices:, actors:)
      owner_key = owner_key_for(realm)
      device_index = devices.index_by { |row| Integer(row.fetch("id")) }
      actor_index = actors.index_by(&:id)
      active = roots.select { |root| active_root?(root, realm) }
      failures = active.flat_map { |root| failures_for(root, realm, owner_key, device_index, actor_index) }.tally
      unless failures.empty?
        counts = failures.sort.map! { |category, count| "#{category}=#{count}" }.join(", ")
        raise Refused, "principal cutover preflight refused: #{counts}"
      end

      { checked_active_roots: active.length }
    end

    private

    def active_root?(root, realm)
      status = (realm == "app") ? root.user_token_status_id : root.staff_token_status_id
      status == root.class.token_status_model::ACTIVE
    end

    def owner_key_for(realm)
      case realm
      when "app" then "user_id"
      when "org" then "staff_id"
      else raise ArgumentError, "unsupported principal export realm"
      end
    end

    def failures_for(root, realm, owner_key, devices, actors)
      owner_id = (realm == "app") ? root.user_id : root.staff_id
      device = devices[root.device_session_id]
      actor = actors[owner_id]
      failures = []
      if device.nil?
        failures << :missing_device
      elsif Integer(device.fetch(owner_key)) != owner_id
        failures << :device_owner_mismatch
      end
      if actor.nil?
        failures << :missing_actor
        return failures
      end

      failures.concat(authority_failures(root, actor))
    end

    def authority_failures(root, actor)
      failures = []
      failures << :inactive_actor unless actor.active?
      failures << :admin_locked_actor if actor.admin_locked?
      failures << :epoch_mismatch unless AuthenticationEpochValue.root_current?(root_token: root, actor: actor)
      if root.created_at.nil?
        failures << :missing_root_created_at
      elsif actor.access_token_stale_for_administrative_lock?("iat" => root.created_at.to_i)
        # Integer JWT iat precision matters even when root creation follows a cutoff within one second.
        failures << :administrative_cutoff
      end
      deadline = actor.purge_eligible_at
      if SessionAbsoluteExpiryValue.finite?(deadline) &&
          (!SessionAbsoluteExpiryValue.finite?(root.discard_at) || root.discard_at > deadline)
        failures << :root_outlives_actor_deadline
      end
      failures
    end
  end
end
