# typed: false
# frozen_string_literal: true

# Auth and Visa controller surfaces use the per-host availability gate. Mounted operator tools
# enforce their own authentication and do not run this controller concern.
module FqdnAvailabilityRegistry
  Slot = Data.define(:name, :hostnames)

  SLOT_SOURCES = {
    auth_service: lambda { |hosts|
      [hosts.auth_service.host, ENV["PUBLIC_AUTH_SERVICE_URL"], "auth.app.localhost"]
    },
    auth_staff: lambda { |hosts|
      [hosts.auth_staff.host, ENV["PUBLIC_AUTH_STAFF_URL"], "auth.org.localhost"]
    },
    visa_service: lambda { |hosts|
      [hosts.visa_service.host, ENV["PUBLIC_VISA_SERVICE_URL"], "visa.app.localhost"]
    },
    visa_staff: lambda { |hosts|
      [hosts.visa_staff.host, ENV["PUBLIC_VISA_STAFF_URL"], "visa.org.localhost"]
    },
  }.freeze

  SLOT_NAMES = SLOT_SOURCES.keys.freeze
  FLAG_PREFIX = "fqdn_available_"

  module_function

  def flag_name_for(slot) = :"#{FLAG_PREFIX}#{slot}"

  def flag_names = SLOT_NAMES.map { |slot| flag_name_for(slot) }

  def slot_for(hostname)
    return nil if hostname.blank?

    index.fetch(normalize(hostname), nil)
  end

  def slots
    @slots ||= SLOT_SOURCES.map do |name, source|
      Slot.new(name: name, hostnames: hostnames_from(source))
    end.freeze
  end

  def index
    @index ||= slots.each_with_object({}) do |slot, map|
      slot.hostnames.each do |hostname|
        claimed = map[hostname]
        if claimed && claimed != slot.name
          raise ArgumentError,
                "FQDN #{hostname} is claimed by both #{claimed} and #{slot.name}; " \
                "one hostname cannot have two availability switches"
        end

        map[hostname] = slot.name
      end
    end.freeze
  end

  def hostnames_from(source)
    hostnames =
      source.call(Rails.configuration.x.boot_config.fetch(:hosts)).compact_blank.map do |value|
        normalize(value)
      end
    hostnames.uniq!
    hostnames.freeze
  end
  private_class_method :hostnames_from

  def normalize(value) = value.to_s.strip.downcase
end
