# Access authorization reference-data repair

Date: 2026-11-09 UTC. Full HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`. Extensive pre-existing
uncommitted application, routing, configuration, documentation and test changes affect these
results. They were preserved. This continuation adds only this evidence record to the repository;
the earlier diagnosis record is preserved as a pre-repair observation. No commit was made.

## Authorization and scope

The owner explicitly approved the six-table, 36-row development repair and subsequent
unauthenticated authorization verification proposed in
`evidence/2026-11-09-access-reference-data-R6K2.md`.

Only the two explicitly named development writer databases received fixed reference inserts. No
database was deleted, reset, rebuilt or migrated; no schema or migration marker was changed. No
existing reference rows were updated or deleted. No application validation or code was changed. No
external service, provider, RP or redirect destination was contacted.

## Repair performed

A temporary Python script read the six owning migrations listed in the diagnosis record, resolved
their `STATUS_IDS` constants, and asserted exact equality with the corresponding current concern
catalogs and the approved catalog sizes. The model DEFAULTS references had also been inspected. No
migration up/change method was executed.

`python3 /tmp/access_reference_repair.py` invoked direct `psql -XAt -v ON_ERROR_STOP=1` connections
to the local PostgreSQL `primary` host. Each development writer used one transaction containing the
three targeted catalog inserts with `ON CONFLICT (id) DO NOTHING`. Each transaction checked exact
required-ID coverage before COMMIT. Both commits succeeded. Query output retained only table names,
operation labels and counts; no row values are recorded.

| Development writer | Reference table                                    | Before | Inserted | After | Required IDs missing after |
| ------------------ | -------------------------------------------------- | -----: | -------: | ----: | -------------------------: |
| op_base_app        | `client_oidc_authorization_transaction_statuses`   |      0 |        4 |     4 |                          0 |
| op_base_app        | `client_auth_admission_binding_statuses`           |      0 |        6 |     6 |                          0 |
| op_base_app        | `client_auth_ceremony_session_statuses`            |      0 |        8 |     8 |                          0 |
| op_base_org        | `operator_oidc_authorization_transaction_statuses` |      0 |        4 |     4 |                          0 |
| op_base_org        | `operator_auth_admission_binding_statuses`         |      0 |        6 |     6 |                          0 |
| op_base_org        | `operator_auth_ceremony_session_statuses`          |      0 |        8 |     8 |                          0 |

Total inserted: 36. These fixed reference rows are retained as the repair. The original diagnosis
inventory records other empty or differing reference catalogs; no blanket repair was performed. This
fixes the observed environment, not the general schema-load/seed gap.

## HTTP verification

`bundle exec ruby /tmp/access_authorization_repair_verify.rb` exited zero on the final run. The
temporary development Rails process booted with PostgreSQL connections forced read-only, so
boot-time preference seeding could not insert unrelated reference rows. Logging was directed to the
null sink and OpenTelemetry disabled. After initialization, the temporary process cleared its
connections and removed its read-only startup option to allow the approved request writes. The
read-only option was local to that process, not a server/database configuration change.

Temporary Puma listened only on loopback port 3814. Net::HTTP sent one unauthenticated GET to Visa
`/oauth/authorize` for each realm, using the configured Visa Host and the registry's Base client and
exact realm callback, code response type, openid scope, generated state/nonce and S256 PKCE. No
authentication cookie was supplied. Authorization/admission records and local handoff state created
by these approved requests were retained; no data cleanup was attempted.

| Realm | HTTP | Embedded destination matches configured Auth host | Destination is sign-in sentry | Entry reference present | no-store |
| ----- | ---: | ------------------------------------------------- | ----------------------------- | ----------------------- | -------- |
| App   |  303 | true                                              | true                          | true                    | true     |
| Org   |  303 | true                                              | true                          | true                    | true     |

The sign-in entry path was `/sign/in/sentry`. Responses route through Jump. The harness inspected
the locally generated Jump payload in memory to compare its destination; this is not independent
signature verification or evidence of external Jump delivery. Redirects were never followed. No raw
request URL, Location, token, cookie, reference ID or database row value is retained here. Puma
stopped in ensure; `ss -ltn '( sport = :3814 )'` subsequently showed no listener.

The first two verification attempts stopped before serving requests because the temporary harness
used an outdated Puma Events constructor (ArgumentError). Correcting that harness to the installed
zero-argument constructor allowed the final run above. No application change was needed. Docker is
unavailable in this executor, as in the original acceptance work; these are results from the
available development runtime, not verified container execution.

## Final verification and limits

Re-ran `python3 /tmp/access_reference_audit.py` using direct read-only SELECTs after HTTP
verification. Development authorization status counts remain four per realm with zero required IDs
missing; test authorization status counts remain four per realm with zero required IDs missing. No
test DB writes were performed. Exact coverage for the other four repaired catalogs was checked
inside the committed repair transactions. No behavior tests were added because this was a data-only
repair; the real HTTP requests verify the affected unauthenticated entry behavior.

The observed 422/status-blank failure is resolved for both realms. Auth destination delivery,
authenticated sign-in completion, unrelated empty reference catalogs and the other acceptance
backlog items remain outside this verification. No validation was weakened.

Temporary script SHA-256 identifiers (scripts are not repository artifacts):

- Repair: `cfe2bacf0eeaf49ab5f9d3221ca04620ff379a4c60cf75d9a948fb356b2b257e`
- Final HTTP verification: `eb1a30313c140a061a6c5610322096637c6e5753c47a1705c8581d5da8be3574`
