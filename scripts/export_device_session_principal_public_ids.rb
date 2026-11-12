# frozen_string_literal: true

unless ENV.fetch("PGOPTIONS") == "-c default_transaction_read_only=on"
  raise ArgumentError, "principal export requires PostgreSQL read-only connections before application boot"
end

require_relative "../config/environment"
require "csv"
require "digest"
require "pg"
require_relative "device_session_principal_export_preflight"

# Run before removing Zenith database configuration. Output contains identity mappings;
# keep it outside tracked files, restrict access, and transfer its SHA256 separately.
realm, output_path = ARGV
unless %w(app org).include?(realm) && output_path.is_a?(String) && !output_path.empty? && ARGV.length == 2
  abort "Usage: RAILS_ENV=<environment> bundle exec ruby " \
        "scripts/export_device_session_principal_public_ids.rb <app|org> <private.csv>"
end
owner, actor_column, actor_table = (realm == "app") ? %w(client user_id clients) : %w(operator staff_id operators)
connections = []
begin
  %W(op_base_#{realm} #{realm}_zenith).each do |name|
    config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: name)
    raise RuntimeError, "missing configured writer #{name}" unless config && !config.replica?

    settings = config.configuration_hash
    connections << PG.connect(
      host: settings[:host], port: settings[:port], dbname: settings.fetch(:database),
      user: settings[:username], password: settings[:password],
    )
    connections.last.exec("BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY")
  end
  device_connection, principal_connection = connections
  sessions = device_connection.exec("SELECT id, #{actor_column} FROM #{owner}_device_sessions ORDER BY id").to_a
  root_model, actor_model =
    (realm == "app") ? [ClientToken, Client] : [OperatorToken, Operator]
  status_column = (realm == "app") ? "user_token_status_id" : "staff_token_status_id"
  roots =
    device_connection.exec(
      "SELECT id, #{actor_column}, device_session_id, #{status_column}, authentication_epoch, created_at, discard_at " \
      "FROM #{owner}_tokens ORDER BY id",
    ).map { |row| root_model.instantiate(row) }
  actor_ids = sessions.map { |session| Integer(session.fetch(actor_column)) }
  actor_ids.concat(roots.map { |root| (realm == "app") ? root.user_id : root.staff_id })
  actor_ids.uniq!
  actors =
    principal_connection.exec_params(
      "SELECT * FROM #{actor_table} WHERE id = ANY($1::bigint[])",
      [PG::TextEncoder::Array.new.encode(actor_ids)],
    ).map { |row| actor_model.instantiate(row) }
  preflight = DeviceSessionPrincipalExportPreflight.call(realm:, roots:, devices: sessions, actors:)
  principals =
    actors.to_h do |actor|
      [actor.id.to_s, actor.public_id]
    end
  rows =
    sessions.map do |session|
      subject =
        principals.fetch(session.fetch(actor_column)) {
          raise RuntimeError, "missing principal mapping; export aborted"
        }
      unless subject.is_a?(String) && subject.valid_encoding? && !subject.strip.empty? &&
          subject.index("\0").nil? && subject.length <= 255
        raise RuntimeError, "invalid principal public ID; export aborted"
      end

      [session.fetch("id"), session.fetch(actor_column), subject]
    end
  bytes =
    CSV.generate do |csv|
      csv << %w(device_session_id actor_id principal_public_id)
      rows.each { |row| csv << row }
    end
  File.open(output_path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(bytes) }
  puts "Preflight checked #{preflight.fetch(:checked_active_roots)} ACTIVE-status roots"
  puts "Exported #{rows.length} device-session mappings; SHA256=#{Digest::SHA256.hexdigest(bytes)}"
ensure
  connections.each do |connection|
    connection.exec("ROLLBACK") unless connection.finished?
    connection.close unless connection.finished?
  end
end
