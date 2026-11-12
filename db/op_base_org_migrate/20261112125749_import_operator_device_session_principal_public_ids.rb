# frozen_string_literal: true

require "csv"
require "digest"

# Export exact subjects before removing Zenith connection ownership. No actor models or
# retired database connections are required when replaying this migration.
class ImportOperatorDeviceSessionPrincipalPublicIds < ActiveRecord::Migration[8.2]
  def up
    # Serialize device-row changes during the exact, fully validated one-off identity import.
    safety_assured { execute("LOCK TABLE operator_device_sessions IN SHARE ROW EXCLUSIVE MODE") }
    sessions = select_rows("SELECT id, staff_id, principal_public_id FROM operator_device_sessions ORDER BY id")
    return if sessions.empty? # An explicitly empty rebuild has no historical subjects to import.

    mapping = read_mapping
    unless mapping.keys.sort == sessions.pluck(0).sort && sessions.all? { |id, actor_id, current|
      mapping.fetch(id)[0] == actor_id && (current.nil? || current == mapping.fetch(id)[1])
    }
      raise ActiveRecord::MigrationError, "principal subject export does not match device sessions"
    end

    mapping.each do |id, (_, subject)|
      # No callbacks or cross-database reads; only the approved identity column is populated.
      safety_assured do
        # Bound native execution keeps identity mappings out of migration SQL announcements.
        result = connection.raw_connection.exec_params(
          "UPDATE operator_device_sessions SET principal_public_id = $1 WHERE id = $2", [subject, id],
        )
        raise ActiveRecord::MigrationError, "device session changed during identity import" unless result.cmd_tuples == 1
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "historical principal subjects must be preserved"
  end

  private

  def read_mapping
    bytes = File.binread(ENV.fetch("OPERATOR_DEVICE_SESSION_PRINCIPAL_PUBLIC_IDS_CSV"))
    expected = ENV.fetch("OPERATOR_DEVICE_SESSION_PRINCIPAL_PUBLIC_IDS_SHA256")
    unless expected.match?(/\A[0-9a-f]{64}\z/) && Digest::SHA256.hexdigest(bytes) == expected
      raise ActiveRecord::MigrationError, "principal subject export checksum mismatch"
    end

    csv = CSV.parse(bytes.force_encoding(Encoding::UTF_8), headers: true)
    unless csv.headers == %w(device_session_id actor_id principal_public_id)
      raise ActiveRecord::MigrationError, "invalid principal subject export headers"
    end

    parse_mapping(csv)
  rescue CSV::MalformedCSVError, Encoding::InvalidByteSequenceError, ArgumentError
    raise ActiveRecord::MigrationError, "malformed principal subject export"
  end

  def parse_mapping(csv)
    mapping = {}
    actor_subjects = {}
    csv.each do |row|
      id, actor_id, subject = row.fields
      unless valid_export_row?(row.fields)
        raise ActiveRecord::MigrationError, "malformed principal subject export row"
      end
      if mapping.key?(id.to_i) || (actor_subjects.key?(actor_id.to_i) && actor_subjects[actor_id.to_i] != subject)
        raise ActiveRecord::MigrationError, "duplicate or contradictory principal subject export"
      end

      mapping[id.to_i] = [actor_id.to_i, subject]
      actor_subjects[actor_id.to_i] = subject
    end
    mapping
  end

  def valid_export_row?(fields)
    id, actor_id, subject = fields
    fields.length == 3 && id&.match?(/\A[1-9][0-9]*\z/) && actor_id&.match?(/\A[1-9][0-9]*\z/) &&
      subject.is_a?(String) && subject.valid_encoding? && !subject.strip.empty? &&
      subject.index("\0").nil? && subject.length <= 255
  end
end
