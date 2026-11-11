# frozen_string_literal: true

# PostgreSQL role ownership and column ACLs have no Active Record schema DSL.
# Owner-approved preparation only; see specs/access-identifier-hmac-credentials/authority-repair.md.
# rubocop:disable I18n/RailsI18n/DecorateString
require_relative "20261008025009_add_operator_identifier_hmac_maintenance"

class RestoreOperatorIdentifierHmacAuthority < AddOperatorIdentifierHmacMaintenance
  public

  def up
    safety_assured do
      connection.transaction do
        execute("SET LOCAL lock_timeout = '5s'")
        inspect_installation!
        CONTACTS.each do |channel, facts|
          ensure_role!(channel, :definer)
          ensure_role!(channel, :caller)
          definer = quote_role(channel, :definer)
          caller = quote_role(channel, :caller)
          table = facts.fetch(:table)
          digest = facts.fetch(:digest)
          execute("GRANT USAGE ON SCHEMA public TO #{definer}, #{caller}")
          execute("GRANT SELECT(id, #{digest}), UPDATE(#{digest}) ON public.#{table} TO #{definer}")
          execute("GRANT INSERT ON public.#{AUDIT_TABLE} TO #{definer}")
          execute("GRANT USAGE ON SEQUENCE public.#{AUDIT_TABLE}_id_seq TO #{definer}")
          restrict_function_authority!(rotation_signature(table), definer, caller)
        end
        verify_repaired_authority!
      end
    end
  end

  # Suspend maintenance safely; never restore PUBLIC execution or erase audit history.
  # Isolated roles/grants remain because templates may share their cluster-wide dependencies.
  def down
    safety_assured do
      connection.transaction do
        execute("SET LOCAL lock_timeout = '5s'")
        inspect_installation!
        executor = connection.select_value("SELECT current_user")
        if @domains.values.any? { |domain| domain.value?(executor) }
          raise ActiveRecord::MigrationError, "rollback requires an independent migration executor"
        end

        CONTACTS.each do |channel, facts|
          signature = rotation_signature(facts.fetch(:table))
          execute("REVOKE ALL ON FUNCTION #{signature} FROM PUBLIC, #{quote_role(channel, :caller)}")
          execute("ALTER FUNCTION #{signature} OWNER TO #{connection.quote_column_name(executor)}")
        end
      end
    end
  end

  private

  def rotation_signature(table)
    "public.rotate_#{table}_hmac(bigint, text, text, uuid)"
  end

  # Preserve migration-created role identities carried by templates, not clone database names.
  def role_name(channel, kind)
    @domains.fetch(channel).fetch(kind)
  end

  def inspect_installation!
    @domains =
      CONTACTS.to_h do |channel, facts|
        source = function_facts(rotation_signature(facts.fetch(:table))).fetch("prosrc")
        pattern = /IF current_user <> '(umaxica_org_#{channel}_hmac_definer_[0-9a-f]{12})' THEN/
        match = pattern.match(source)
        raise ActiveRecord::MigrationError, "unrecognized identifier maintenance identity" unless match

        definer = match[1]
        [channel, { definer: definer, caller: definer.sub("_definer_", "_caller_") }]
      end
    CONTACTS.each do |channel, facts|
      verify_function!(rotation_signature(facts.fetch(:table)), rotation_body(channel, facts), definer: true)
      verify_existing_role!(channel, :definer, facts)
      verify_existing_role!(channel, :caller, facts)
      verify_no_public_relation_grants!(facts.fetch(:table))
    end
    verify_function!("public.enforce_operator_rotation_audit()", audit_body, definer: false)
    verify_trigger!("public.enforce_operator_rotation_audit()", AUDIT_TABLE.to_s, 23)
    verify_no_public_relation_grants!(AUDIT_TABLE.to_s)
    return if connection.select_value("SELECT to_regclass('public.#{AUDIT_TABLE}_id_seq') IS NOT NULL")

    raise ActiveRecord::MigrationError, "identifier rotation audit sequence is missing"

  end

  def function_facts(signature)
    row = connection.select_one(<<~SQL.squish)
      SELECT p.oid, p.prosrc, r.rolname AS owner,
             l.lanname = 'plpgsql' AND p.prokind = 'f' AND NOT p.proisstrict AND
             NOT p.proleakproof AND p.provolatile = 'v' AND p.proparallel = 'u' AND
             p.pronargdefaults = 0 AND p.proconfig = ARRAY['search_path=pg_catalog, pg_temp'] AS settings_valid,
             p.prosecdef,
             p.prorettype = 'boolean'::regtype AND p.proargnames =
               ARRAY['p_record_id', 'p_new_digest', 'p_expected_digest', 'p_operation_ref'] AS returns_boolean,
             p.prorettype = 'trigger'::regtype AS returns_trigger
      FROM pg_proc p
      JOIN pg_roles r ON r.oid = p.proowner
      JOIN pg_language l ON l.oid = p.prolang
      WHERE p.oid = to_regprocedure(#{connection.quote(signature)})
    SQL
    raise ActiveRecord::MigrationError, "required identifier maintenance function is missing" unless row

    row
  end

  def verify_function!(signature, expected_body, definer:)
    row = function_facts(signature)
    valid = row.fetch("settings_valid") && row.fetch("prosecdef") == definer &&
      row.fetch(definer ? "returns_boolean" : "returns_trigger") &&
      row.fetch("prosrc").split.join(" ") == expected_body.split.join(" ")
    raise ActiveRecord::MigrationError, "identifier maintenance function contract differs" unless valid
  end

  def verify_trigger!(signature, table, type)
    valid = connection.select_value(<<~SQL.squish)
      SELECT count(*) = 1 AND bool_and(
        tgrelid = 'public.#{table}'::regclass AND tgenabled = 'O' AND tgtype = #{type} AND
        tgnargs = 0 AND tgqual IS NULL AND tgattr = ''::int2vector
      )
      FROM pg_trigger WHERE tgfoid = #{connection.quote(signature)}::regprocedure AND NOT tgisinternal
    SQL
    raise ActiveRecord::MigrationError, "identifier maintenance guard attachment differs" unless valid
  end

  def verify_no_public_relation_grants!(table)
    count = connection.select_value(<<~SQL.squish).to_i
      SELECT count(*) FROM (
        SELECT a.grantee FROM pg_class c CROSS JOIN LATERAL aclexplode(c.relacl) a
        WHERE c.oid = 'public.#{table}'::regclass
        UNION ALL
        SELECT a.grantee FROM pg_attribute att CROSS JOIN LATERAL aclexplode(att.attacl) a
        WHERE att.attrelid = 'public.#{table}'::regclass
      ) grants WHERE grantee = 0
    SQL
    raise ActiveRecord::MigrationError, "identifier relation has unexpected PUBLIC authority" unless count.zero?
  end

  def verify_existing_role!(channel, kind, facts)
    name = role_name(channel, kind)
    role_oid = connection.select_value("SELECT oid FROM pg_roles WHERE rolname = #{connection.quote(name)}")
    # Absence is the approved repair case; present roles must already be isolated.
    return if role_oid.nil?

    ensure_role!(channel, kind)
    table = facts.fetch(:table)
    expected_function = function_facts(rotation_signature(table)).fetch("oid")
    permissions = connection.select_rows(<<~SQL.squish)
      SELECT 'schema', n.nspname, '', a.privilege_type, a.is_grantable
      FROM pg_namespace n CROSS JOIN LATERAL aclexplode(n.nspacl) a WHERE a.grantee = #{role_oid}
      UNION ALL
      SELECT 'relation', n.nspname || '.' || c.relname, '', a.privilege_type, a.is_grantable
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
      CROSS JOIN LATERAL aclexplode(c.relacl) a WHERE a.grantee = #{role_oid}
      UNION ALL
      SELECT 'column', n.nspname || '.' || c.relname, att.attname, a.privilege_type, a.is_grantable
      FROM pg_attribute att JOIN pg_class c ON c.oid = att.attrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      CROSS JOIN LATERAL aclexplode(att.attacl) a WHERE a.grantee = #{role_oid}
      UNION ALL
      SELECT 'function', p.oid::text, '', a.privilege_type, a.is_grantable
      FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a WHERE a.grantee = #{role_oid}
      UNION ALL
      SELECT 'database', d.datname, '', a.privilege_type, a.is_grantable
      FROM pg_database d CROSS JOIN LATERAL aclexplode(d.datacl) a WHERE a.grantee = #{role_oid}
      UNION ALL
      SELECT 'default', d.oid::text, '', a.privilege_type, a.is_grantable
      FROM pg_default_acl d CROSS JOIN LATERAL aclexplode(d.defaclacl) a WHERE a.grantee = #{role_oid}
    SQL
    allowed = expected_role_grants(kind, facts, expected_function)
    unless (permissions - allowed).empty?
      raise ActiveRecord::MigrationError, "identifier maintenance role has unexpected grants"
    end

    other_owners = connection.select_value(<<~SQL.squish).to_i
      SELECT count(*) FROM pg_shdepend
      WHERE refclassid = 'pg_authid'::regclass AND refobjid = #{role_oid} AND deptype = 'o' AND
        dbid = (SELECT oid FROM pg_database WHERE datname = current_database()) AND
        NOT (classid = 'pg_proc'::regclass AND objid = #{expected_function})
    SQL
    if other_owners.positive? || (kind == :caller && function_facts(rotation_signature(table)).fetch("owner") == name)
      raise ActiveRecord::MigrationError, "identifier maintenance role owns unexpected objects"
    end
  end

  def expected_role_grants(kind, facts, expected_function)
    table = facts.fetch(:table)
    digest = facts.fetch(:digest)
    allowed = [["schema", "public", "", "USAGE", false],
               ["function", expected_function.to_s, "", "EXECUTE", false],]
    if kind == :definer
      allowed.concat(
        [
          ["column", "public.#{table}", "id", "SELECT", false],
          ["column", "public.#{table}", digest, "SELECT", false],
          ["column", "public.#{table}", digest, "UPDATE", false],
          ["relation", "public.#{AUDIT_TABLE}", "", "INSERT", false],
          ["relation", "public.#{AUDIT_TABLE}_id_seq", "", "USAGE", false],
        ],
      )
    end
    allowed
  end

  def verify_repaired_authority!
    CONTACTS.each do |channel, facts|
      row = function_facts(rotation_signature(facts.fetch(:table)))
      unless row.fetch("owner") == role_name(channel, :definer)
        raise ActiveRecord::MigrationError, "identifier maintenance owner repair failed"
      end

      count = connection.select_value(<<~SQL.squish).to_i
        SELECT count(*) FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
        LEFT JOIN pg_roles r ON r.oid = a.grantee
        WHERE p.oid = #{row.fetch("oid")} AND
          (a.grantee = 0 OR r.rolname NOT IN (
            #{connection.quote(role_name(channel, :definer))}, #{connection.quote(role_name(channel, :caller))}
          ) OR a.privilege_type <> 'EXECUTE' OR a.is_grantable)
      SQL
      executable = connection.select_value(<<~SQL.squish)
        SELECT has_function_privilege(#{connection.quote(role_name(channel, :caller))},
                                      #{connection.quote(rotation_signature(facts.fetch(:table)))}, 'EXECUTE')
      SQL
      unless count.zero? && executable
        raise ActiveRecord::MigrationError, "identifier maintenance function ACL repair failed"
      end
    end
  end

  def rotation_body(channel, facts)
    table = facts.fetch(:table)
    digest = facts.fetch(:digest)
    <<~SQL.squish
      DECLARE prior_digest text;
            BEGIN
              IF current_user <> #{connection.quote(role_name(channel, :definer))} THEN
                RAISE EXCEPTION 'identifier rotation function owner is invalid';
              END IF;
              IF p_record_id IS NULL OR p_record_id <= 0 OR p_operation_ref IS NULL OR
                 p_new_digest IS NULL OR p_new_digest !~ '^[0-9a-f]{64}$' THEN
                RAISE EXCEPTION 'invalid identifier rotation arguments';
              END IF;
              SELECT #{digest} INTO prior_digest FROM public.#{table} WHERE id = p_record_id FOR UPDATE;
              IF NOT FOUND THEN
                RAISE EXCEPTION 'identifier rotation source is unavailable';
              END IF;
              IF prior_digest IS DISTINCT FROM p_expected_digest THEN
                RAISE EXCEPTION 'identifier rotation source changed' USING ERRCODE = '40001';
              END IF;
              IF prior_digest IS NOT DISTINCT FROM p_new_digest THEN
                RETURN FALSE;
              END IF;
              UPDATE public.#{table} SET #{digest} = p_new_digest WHERE id = p_record_id;
              INSERT INTO public.#{AUDIT_TABLE}(operation_ref, channel, record_id, actor_role, occurred_at)
                VALUES (p_operation_ref, '#{channel}', p_record_id, session_user, clock_timestamp());
              RETURN TRUE;
            END;
    SQL
  end

  def audit_body
    email_role = connection.quote(role_name(:email, :definer))
    telephone_role = connection.quote(role_name(:telephone, :definer))
    <<~SQL.squish
      BEGIN
        IF TG_OP = 'UPDATE' THEN
          RAISE EXCEPTION 'identifier rotation audit is append-only';
        END IF;
        IF NOT ((current_user = #{email_role} AND NEW.channel = 'email') OR
                (current_user = #{telephone_role} AND NEW.channel = 'telephone')) THEN
          RAISE EXCEPTION 'identifier rotation audit requires its domain function';
        END IF;
        RETURN NEW;
      END;
    SQL
  end
end

# rubocop:enable I18n/RailsI18n/DecorateString
