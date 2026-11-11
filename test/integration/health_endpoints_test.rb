# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# End-to-end contract for the health endpoints on every declared surface.
#
#   GET /health            -> text/plain seven-line aggregate
#                            (title, namespace, status, startup, liveness, readiness, timestamp)
#   GET /health/{probe}    -> text/plain "ok\n" / HTTP 200 or "unavailable\n" / HTTP 503
#   GET /api/v0/health.json -> application/json {"status":..,"checks":{..}}, 406 on a non-JSON Accept
class HealthEndpointsTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
      controller: "auth/app/healths",
      liveness_controller: "auth/app/health/livenesses",
      readiness_controller: "auth/app/health/readinesses",
      startup_controller: "auth/app/health/startups",
      json_controller: "auth/app/api/v0/healths",
      profile: Health::Profiles::SignApp,
    },
    {
      host: ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
      controller: "auth/org/healths",
      liveness_controller: "auth/org/health/livenesses",
      readiness_controller: "auth/org/health/readinesses",
      startup_controller: "auth/org/health/startups",
      json_controller: "auth/org/api/v0/healths",
      profile: Health::Profiles::SignOrg,
    },
    {
      host: ENV.fetch("PUBLIC_VISA_SERVICE_URL"),
      controller: "visa/app/healths",
      liveness_controller: "visa/app/health/livenesses",
      readiness_controller: "visa/app/health/readinesses",
      startup_controller: "visa/app/health/startups",
      json_controller: "visa/app/api/v0/healths",
      profile: Health::Profiles::App,
    },
    {
      host: ENV.fetch("PUBLIC_VISA_STAFF_URL"),
      controller: "visa/org/healths",
      liveness_controller: "visa/org/health/livenesses",
      readiness_controller: "visa/org/health/readinesses",
      startup_controller: "visa/org/health/startups",
      json_controller: "visa/org/api/v0/healths",
      profile: Health::Profiles::Org,
    },
  ].freeze

  PROBES = %w(liveness readiness startup).freeze

  EDGE_NAMESPACE_HOSTS = {
    ENV.fetch("PUBLIC_AUTH_SERVICE_URL") => "auth/app",
    ENV.fetch("PUBLIC_AUTH_STAFF_URL") => "auth/org",
    ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "visa/app",
    ENV.fetch("PUBLIC_VISA_STAFF_URL") => "visa/org",
  }.freeze

  test "surface routes resolve to concrete local controllers with exact profiles" do
    SURFACES.each do |surface|
      assert_health_route(surface[:host], "/health", surface[:controller])
      assert_health_route(surface[:host], "/health/liveness", surface[:liveness_controller])
      assert_health_route(surface[:host], "/health/readiness", surface[:readiness_controller])
      assert_health_route(surface[:host], "/health/startup", surface[:startup_controller])
      assert_health_route(surface[:host], "/api/v0/health.json", surface[:json_controller])

      [
        surface[:controller],
        surface[:liveness_controller],
        surface[:readiness_controller],
        surface[:startup_controller],
        surface[:json_controller],
      ].each do |controller|
        controller_class = "#{controller}_controller".camelize.constantize

        assert_same surface[:profile], controller_class.const_get(:HEALTH_PROFILE, false)
      end
    end
  end

  # One Rails process answers on every surface hostname. The wire probe body is now just "ok\n",
  # so the surface is no longer named in the response; instead every surface must route to its own
  # <realm>/<surface> controller namespace, and no two surfaces may share one. That is what keeps
  # a misdirected request between two hostnames from being silently served by the wrong surface.
  test "every surface routes health to a unique <realm>/<surface> controller namespace" do
    namespaces =
      SURFACES.map do |surface|
        controllers = [
          surface[:controller], surface[:liveness_controller], surface[:readiness_controller],
          surface[:startup_controller], surface[:json_controller],
        ]
        prefixes = controllers.map { |controller| controller.split("/").first(2).join("/") }

        assert_equal 1, prefixes.uniq.length,
                     "#{surface[:host]} spreads its health controllers across namespaces: #{prefixes.inspect}"

        prefixes.first
      end

    assert_equal namespaces.length, namespaces.uniq.length,
                 "two surfaces share a controller namespace: #{namespaces.inspect}"
  end

  test "all health controllers use the shared rendering concern" do
    SURFACES.each do |surface|
      [
        surface[:controller],
        surface[:liveness_controller],
        surface[:readiness_controller],
        surface[:startup_controller],
        surface[:json_controller],
      ].each do |controller|
        controller_class = "#{controller}_controller".camelize.constantize

        assert_includes controller_class.ancestors, ::HealthCheckRendering
      end
    end
  end

  test "GET /health is a text/plain seven-line aggregate, never HTML or JSON, with no polling" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    get "/health"

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_not_equal "text/html", response.media_type
    assert_not_equal "application/json", response.media_type
    assert_match(
      Regexp.new(
        "\\Atitle: Health status\\nnamespace: auth/app\\nstatus: \\w+\\nstartup: \\w+\\n" \
        "liveness: \\w+\\nreadiness: \\w+\\ntimestamp: [^\\n]+Z\\n\\z",
      ),
      response.body,
    )
    assert_no_match(/<html|<!doctype/i, response.body)
    assert_no_match(/fetch\s*\(|setInterval|setTimeout|EventSource|WebSocket/i, response.body)
    assert_no_match(/health\.json/i, response.body)
  end

  # Two different refusals, and the difference is the point. Asking for JSON with an `Accept` header
  # is answered -- with plain text, because that is the only representation the endpoint has, and a
  # probe that 406s because its client sent a boilerplate `Accept` is a probe that reports an
  # outage. Asking for it with a `.json` path suffix is a 404, because `/api/v0/health.json` is a
  # real endpoint serving real JSON at nearly the same spelling, and answering the suffix with
  # text/plain would tell that caller it had reached the JSON one.
  test "GET /health answers an Accept header with text and does not route a .json suffix" do
    SURFACES.each do |surface|
      host! surface[:host]

      get "/health.json"

      assert_response :not_found, surface[:host]

      get "/health", headers: { "Accept" => "application/json" }

      assert_response :success
      assert_equal "text/plain", response.media_type
      assert_no_match(/\A\s*[{\[]/, response.body)
    end
  end

  test "text probes render \"ok\\n\" regardless of Accept header, and reject a format suffix" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    PROBES.each do |probe|
      [nil, "text/html", "*/*", "application/json"].each do |accept|
        headers = accept ? { "Accept" => accept } : {}

        get "/health/#{probe}", headers: headers

        assert_includes [200, 503], response.status
        assert_equal "text/plain", response.media_type
        assert_not_equal "application/json", response.media_type
        assert_includes ["ok\n", "unavailable\n"], response.body
        assert_not_predicate response, :redirect?
      end
    end

    # A format suffix is not a route here, so a browser-shaped request for one gets a 404 rather
    # than plain text under an HTML-looking URL.
    get "/health/readiness.html", headers: { "Accept" => "text/html" }

    assert_response :not_found

    get "/health/startup.html", headers: { "Accept" => "text/html" }

    assert_response :not_found
  end

  test "liveness remains dependency free" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    Health::ReadinessCheck.stub(:call, ->(_profile:) { raise RuntimeError, "readiness loaded" }) do
      # Valkey is not represented here: the removal of the generic REDIS_CLIENT
      # (adr/solid-cache-removal-and-valkey-cache-separation.md) left liveness
      # with no Redis-shaped dependency to stub. Rails.cache and the rate-limit
      # store are Valkey-backed, but liveness reaches neither.
      ActiveRecord::Base.stub(:connection, -> { raise RuntimeError, "database touched" }) do
        get "/health/liveness"
      end
    end

    assert_response :success
    assert_equal "ok\n", response.body
    assert_equal "text/plain", response.media_type
  end

  test "readiness does not raise prosopite n plus one errors" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    assert_health_request_has_no_prosopite_n_plus_one("/health/readiness")
  end

  test "health snapshot does not raise prosopite n plus one errors" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    assert_health_request_has_no_prosopite_n_plus_one("/health")
  end

  test "startup remains dependency light" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    Health::Checks::Database.stub(:new, ->(*) { raise RuntimeError, "database check built" }) do
      get "/health/startup"
    end

    assert_response :success
    assert_equal "ok\n", response.body
  end

  test "Visa App readiness ignores Org-only dependencies" do
    host! ENV.fetch("PUBLIC_VISA_SERVICE_URL")

    assert_readiness_does_not_build(OpBaseOrgRecord)
  end

  test "Auth readiness ignores Visa-only dependencies" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    assert_readiness_does_not_build(AppRpRecord)
  end

  test "new database base classes do not affect existing surfaces by default" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    new_record_base = Class.new(ApplicationRecord)

    assert_readiness_does_not_build(new_record_base)
  end

  test "probe status codes come from result status" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    assert_probe_status(:ok, :success)
    assert_probe_status(:degraded_acceptable, :success)
    assert_probe_status(:unready, :service_unavailable)
  end

  # An orchestrator acts on the verdict it is handed. A stored 200 keeps traffic going to an
  # instance that has since failed readiness, and a stored 503 keeps it away from one that has
  # recovered, so every health response has to be uncacheable - including the ones that are not
  # a successful probe render.
  test "no health response may be stored by a cache" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    get "/health"

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]

    PROBES.each do |probe|
      get "/health/#{probe}"

      assert_includes [200, 503], response.status
      assert_equal "no-store", response.headers["Cache-Control"], "/health/#{probe} may not be stored"
    end

    get "/api/v0/health.json", headers: { "Accept" => "application/json" }

    assert_includes [200, 503], response.status
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "a failing probe and a refused machine format are uncacheable too" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    unready = Health::CheckResult.new(
      check: :readiness,
      status: :unready,
      surface: Health::Profiles::SignApp.surface_label,
    )

    Health::ReadinessCheck.stub(:call, unready) do
      get "/health/readiness"
    end

    assert_response :service_unavailable
    assert_equal "unavailable\n", response.body
    assert_equal "no-store", response.headers["Cache-Control"]

    get "/api/v0/health.json", headers: { "Accept" => "text/html" }

    assert_response :not_acceptable
    assert_empty response.body
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "probe responses omit topology and exception details" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")
    result = Health::CheckResult.new(
      check: :readiness,
      status: :unready,
      surface: Health::Profiles::SignApp.surface_label,
      dependencies: { "database" => "failed" },
    )

    Health::ReadinessCheck.stub(:call, result) do
      get "/health/readiness"
    end

    assert_equal "unavailable\n", response.body

    forbidden = %w(
      AppPrincipalRecord app_principal app_principal_replica writing reading localhost
      StandardError PG::ConnectionBad Mysql2 database failed
    )

    forbidden.each { |value| assert_not_includes response.body, value }
  end

  test "wrong host is not routed to public health" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://wrong.example.test/health", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://wrong.example.test/api/v0/health.json", method: :get)
    end
  end

  # ------------------------------------------------------------------------------------------------
  # Machine JSON aggregate: GET /api/v0/health.json
  # ------------------------------------------------------------------------------------------------

  test "GET /api/v0/health.json is the pass/warn/fail schema on every declared surface" do
    SURFACES.each do |surface|
      host! surface[:host]

      stub_healthy do
        get "/api/v0/health.json", headers: { "Accept" => "application/json" }
      end

      assert_response :success, "#{surface[:host]} /api/v0/health.json"
      assert_equal "application/json", response.media_type
      assert_not_equal "text/plain", response.media_type
      assert_not_equal "text/html", response.media_type

      body = response.parsed_body

      assert_equal %w(checks namespace status timestamp), body.keys.sort
      assert_equal %w(liveness readiness startup), body.fetch("checks").keys.sort
      assert_includes %w(pass warn fail), body.fetch("status")
      assert_equal surface[:json_controller].split("/").first(2).join("/"), body.fetch("namespace")
      assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/, body.fetch("timestamp"))

      body.fetch("checks").each_value do |check|
        assert_equal %w(status), check.keys
        assert_includes %w(pass warn fail), check.fetch("status")
      end

      assert_equal "pass", body.fetch("status")
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "GET /api/v0/health.json identifies the controller namespace selected for every edge host" do
    namespaces =
      EDGE_NAMESPACE_HOSTS.map do |host, expected_namespace|
        host!(host)

        stub_healthy do
          get("/api/v0/health.json", headers: { "Accept" => "application/json" })
        end

        assert_response :success, "#{host} /api/v0/health.json"
        assert_equal expected_namespace, response.parsed_body.fetch("namespace"), host

        response.parsed_body.fetch("namespace")
      end

    assert_equal EDGE_NAMESPACE_HOSTS.length, namespaces.uniq.length
  end

  test "GET /health identifies the controller namespace selected for every edge host" do
    EDGE_NAMESPACE_HOSTS.each do |host, expected_namespace|
      host! host

      stub_healthy do
        get "/health"
      end

      assert_response :success, "#{host} /health"
      assert_includes response.body.lines, "namespace: #{expected_namespace}\n", host
    end
  end

  test "GET /api/v0/health.json refuses a non-JSON Accept with an empty 406" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    ["text/html", "text/plain"].each do |accept|
      get "/api/v0/health.json", headers: { "Accept" => accept }

      assert_response :not_acceptable, "Accept: #{accept}"
      assert_empty response.body
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "GET /api/v0/health.json is 200 on pass and 503 on fail, and a readiness outage keeps liveness passing" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    stub_healthy do
      get "/api/v0/health.json", headers: { "Accept" => "application/json" }
    end

    assert_response :success
    assert_equal "pass", response.parsed_body.fetch("status")

    unready = Health::CheckResult.new(
      check: :readiness, status: :unready, surface: Health::Profiles::SignApp.surface_label,
    )

    Health::ReadinessCheck.stub(:call, unready) do
      get "/api/v0/health.json", headers: { "Accept" => "application/json" }
    end

    assert_response :service_unavailable
    body = response.parsed_body

    assert_equal "fail", body.fetch("status")
    assert_equal "fail", body.dig("checks", "readiness", "status")
    assert_equal "pass", body.dig("checks", "liveness", "status")
    assert_equal "pass", body.dig("checks", "startup", "status")
  end

  test "GET /api/v0/health.json body leaks no internal detail" do
    host! ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")

    result = Health::CheckResult.new(
      check: :readiness,
      status: :unready,
      surface: Health::Profiles::SignApp.surface_label,
      dependencies: { "database" => "failed" },
    )

    Health::ReadinessCheck.stub(:call, result) do
      get "/api/v0/health.json", headers: { "Accept" => "application/json" }
    end

    # Rails.root is `/app` in containerized CI; the health JSON namespace is
    # `auth/app`, which contains that substring. Forbid path leaks with a
    # trailing separator / quoted absolute path instead of the bare root.
    forbidden = [
      "secret_key_base", "git", "AppPrincipalRecord", "PG::",
      "StandardError", "localhost", "database", "failed", "readiness loaded",
    ]

    forbidden.each { |value| assert_not_includes response.body, value }
    assert_no_match(%r{#{Regexp.escape(Rails.root.to_s)}/}, response.body)
    assert_not_includes response.body, %("#{Rails.root}")
    assert_no_match(/\.rb:\d+|backtrace|Traceback/, response.body)
  end

  test "every declared health surface executes its controller show actions" do
    SURFACES.each do |surface|
      host! surface[:host]

      profile = surface[:profile]
      liveness = Health::CheckResult.new(check: :liveness, status: :ok, surface: profile.surface_label)
      readiness = Health::CheckResult.new(
        check: :readiness,
        status: :ok,
        surface: profile.surface_label,
        dependencies: {},
      )
      startup = Health::CheckResult.new(check: :startup, status: :ok, surface: profile.surface_label)
      snapshot = Health::CheckResult.new(
        check: :health,
        status: :ok,
        surface: profile.surface_label,
        dependencies: {
          "liveness" => liveness.as_public_json,
          "readiness" => readiness.as_public_json,
          "startup" => startup.as_public_json,
        },
      )

      Health::LivenessCheck.stub(:call, liveness) do
        Health::ReadinessCheck.stub(:call, readiness) do
          Health::StartupCheck.stub(:call, startup) do
            Health::SnapshotCheck.stub(:call, snapshot) do
              get "/health"

              assert_response :success
              assert_equal "text/plain", response.media_type
              namespace = surface[:controller].split("/").first(2).join("/")

              assert_match(
                Regexp.new(
                  "\\Atitle: Health status\\nnamespace: #{namespace}\\nstatus: ok\\nstartup: ok\\n" \
                  "liveness: ok\\nreadiness: ok\\ntimestamp: [^\\n]+Z\\n\\z",
                ),
                response.body,
              )

              PROBES.each do |probe|
                get "/health/#{probe}"

                assert_response :success
                assert_equal "text/plain", response.media_type
                assert_equal "ok\n", response.body
              end

              get "/api/v0/health.json", headers: { "Accept" => "application/json" }

              assert_response :success
              assert_equal "application/json", response.media_type
              assert_equal "pass", response.parsed_body.fetch("status")
            end
          end
        end
      end
    end
  end

  private

  def stub_healthy(&)
    profile = Health::Profiles::App
    ok = ->(check) { Health::CheckResult.new(check: check, status: :ok, surface: profile.surface_label) }

    Health::LivenessCheck.stub(:call, ok.call(:liveness)) do
      Health::ReadinessCheck.stub(:call, ok.call(:readiness)) do
        Health::StartupCheck.stub(:call, ok.call(:startup), &)
      end
    end
  end

  def assert_health_route(host, path, controller)
    recognized = Rails.application.routes.recognize_path("http://#{host}#{path}", method: :get)

    assert_equal controller, recognized[:controller]
    assert_equal "show", recognized[:action]
  end

  def assert_probe_status(status, expected_response)
    result = Health::CheckResult.new(
      check: :readiness,
      status: status,
      surface: Health::Profiles::SignApp.surface_label,
    )

    Health::ReadinessCheck.stub(:call, result) do
      get("/health/readiness")
    end

    assert_response expected_response
  end

  def assert_readiness_does_not_build(forbidden_record_class)
    Health::Checks::Database.stub(
      :new,
      lambda { |record_class:, **_options|
        raise RuntimeError, "unexpected dependency" if record_class == forbidden_record_class

        Struct.new(:result) do
          def call = result
        end.new(Health::DependencyResult.new(kind: :database, status: :ok))
      },
    ) do
      get("/health/readiness")
    end

    assert_response :success
  end

  def assert_health_request_has_no_prosopite_n_plus_one(path)
    Prosopite.pause do
      assert_nothing_raised do
        Prosopite.scan do
          get(path)
        end
      end
    end

    assert_includes [200, 503], response.status
    assert_predicate response.media_type, :present?

    Prosopite.pause do
      Prosopite.tc[:prosopite_query_counter] = Hash.new(0)
      Prosopite.tc[:prosopite_query_holder] = Hash.new { |h, k| h[k] = [] }
      Prosopite.tc[:prosopite_query_caller] = {}
    end
  end
end
