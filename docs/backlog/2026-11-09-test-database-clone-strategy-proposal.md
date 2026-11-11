# Proposal: clone parallel test databases with `STRATEGY = FILE_COPY`

Status: Proposal for evaluation; recorded at the user's request on 2026-11-09. No implementation
change is authorized by this entry. The owner asks an agent on a separate host whose PostgreSQL data
lives on Btrfs or ZFS to evaluate it there first and report whether it speeds up the suite. Stored
in `docs/backlog/` at the user's explicit request.

## Audience and decision requested

You are evaluating this proposal on a host other than the one that wrote it. Decide, with
measurements from your host, whether `ParallelTestDatabaseCloner` should create worker and replica
clones with `CREATE DATABASE ... STRATEGY = FILE_COPY` (optionally with PostgreSQL 18's
`file_copy_method = clone`) instead of the default `WAL_LOG` strategy. Report the numbers listed in
"Measurements to report" and a recommendation: adopt, adopt only with `clone`, or reject.

Run only read-only checks until the owner approves the experiment. The experiment drops and
recreates disposable test clones (`test_*_<worker>`, `test_*_replica_db`); obtain explicit approval
before it, and never touch development databases.

## Current behavior

`test/support/parallel_test_database_cloner.rb` runs before the test workers fork. For every test
writer database it keeps one clone per worker (`test_<name>_db_<n>`), plus one replica clone per
replica configuration (`test_<name>_replica_db`). A clone is rebuilt only when the base database's
schema fingerprint (`schema_sha`, stored as the database comment) changes. A rebuild runs, per
clone:

```sql
DROP DATABASE "<clone>" WITH (FORCE);         -- when the clone exists
CREATE DATABASE "<clone>" TEMPLATE "<source>"; -- default strategy: WAL_LOG
COMMENT ON DATABASE "<clone>" IS '<sha>';
```

`CLONE_THREADS = 8` threads run clones in parallel across distinct template sources.

With 12 workers and 26 writer databases this is about 600 databases (about 10 GB on the measuring
host). Since PostgreSQL 15 the default `WAL_LOG` strategy copies every block of the template through
the write-ahead log.

## Evidence from the originating host (2026-11-09)

Environment: PostgreSQL 18.6 in rootless Podman, data on ext4 over LVM over dm-crypt in a Proxmox
KVM guest, host storage ZFS RAIDZ2 (NVMe) without a separate log device. Full suite 17,165 tests, 12
workers. See `docs/backlog/2026-11-09-host-native-test-suite-latency.md` for all runs.

- Cumulative statistics since the cluster started (several test-database rebuilds that day):
  `pg_stat_wal.wal_bytes` about 27.9 GB, `pg_stat_checkpointer.num_requested` 41 with `num_timed` 0,
  checkpointer fsyncs about 718,000 with `sync_time` about 1,795 s.
- Runs that started shortly after the test databases were rebuilt were much slower (about 5.6-7.7
  tests/s) than runs with cached clones (about 18 tests/s), independent of `synchronous_commit`.
- The owner reports that the same suite ran in about 6 minutes on another system whose PostgreSQL
  data was on Btrfs or ZFS. Which strategy and settings that system used is unknown.

These observations are consistent with clone rebuilding being expensive, but they do not isolate the
clone strategy. No `FILE_COPY` measurement exists yet.

## Hypothesis

1. `STRATEGY = FILE_COPY` copies each template directory at the filesystem level and writes only a
   small WAL record per tablespace, so WAL volume and streaming-replica traffic during a rebuild
   drop sharply.
2. On PostgreSQL 18 with `file_copy_method = clone` and a filesystem that supports reflinks (Btrfs;
   OpenZFS 2.2+ with block cloning enabled; XFS with reflink), each clone becomes a near-instant
   copy-on-write operation with almost no extra space until pages diverge.
3. `FILE_COPY` forces a checkpoint before and after each copy. On storage with slow flushes this can
   cost more than it saves. On the originating host `fsync` is now `off` for the development and
   test cluster, which removes most of that cost; on your host, record what `fsync` is.

## Proposed change (for evaluation only)

In `rebuild_clone`, add the strategy to the `CREATE DATABASE` statement:

```ruby
admin_connection.exec(
  "create database #{admin_connection.quote_ident(clone)} " \
  "template #{admin_connection.quote_ident(source)} strategy = file_copy",
)
```

Optionally, on PostgreSQL 18 with a reflink-capable filesystem, set `file_copy_method = clone` in
the server configuration (it does not affect `WAL_LOG`).

## Preconditions to check on your host (read-only)

- `SELECT version();` — `file_copy_method` exists only in PostgreSQL 18 and later.
- Filesystem under the data directory (`findmnt -T <data dir>` on the host, or inside the container
  `df` / `mount` for `/var/lib/postgresql/data`). For ZFS, whether block cloning is available and
  enabled (OpenZFS 2.2+, module parameter `zfs_bclone_enabled`); for Btrfs, reflink is native.
- Whether the data directory is a named volume or a bind mount (overlayfs would block reflinks).
- Current `fsync`, `synchronous_commit`, `full_page_writes`, `checkpoint_timeout`, `max_wal_size`,
  `shared_buffers`, `file_copy_method`.
- Whether a streaming replica runs `pg_basebackup` at startup; avoid overlapping it with a
  `FILE_COPY` rebuild (see Risks).
- Free space: `clone` needs little; `copy` needs about the size of all clones again.

## Experiment (after approval)

Keep the network mode, worker count (`PARALLEL_WORKERS=12`) and server settings fixed. Enable
`track_wal_io_timing` and `track_io_timing` for the session if allowed.

1. **Micro benchmark, no suite.** Pick the largest test writer database as `<src>`. For each
   strategy, time three runs of:

   ```sql
   CREATE DATABASE bench_clone TEMPLATE <src> STRATEGY = <WAL_LOG|FILE_COPY>;
   DROP DATABASE bench_clone;
   ```

   With PostgreSQL 18, repeat `FILE_COPY` with `file_copy_method = copy` and `= clone`. Record the
   `pg_stat_wal.wal_bytes` and `pg_stat_checkpointer` deltas around each run.

2. **Full rebuild in the suite.** Force all clones to rebuild by dropping the disposable worker and
   replica clones (`test_*_<n>`, `test_*_replica_db`; recreate the replica databases empty as the
   README describes). Run `bin/rails test` once per strategy and record the time until the first
   test starts (clone phase) and the total wall clock.
3. **Steady state.** Run the suite a second time per strategy without dropping clones, to confirm
   the strategy does not affect runs with cached clones.
4. Alternate the order (WAL_LOG, FILE_COPY, FILE_COPY, WAL_LOG) to limit cache and ordering effects.

## Measurements to report

- PostgreSQL version, filesystem, reflink availability, `fsync` / `synchronous_commit` /
  `full_page_writes`, `file_copy_method`.
- Micro benchmark: seconds per clone, WAL bytes per clone, checkpoints requested, for each strategy.
- Suite: clone-phase seconds, total wall clock, `runs, failures, errors`, for each strategy and run.
- Disk usage of the data directory before and after a full rebuild.
- Any errors or warnings in the PostgreSQL log during the experiment.

## Decision criteria

- Adopt `FILE_COPY` when the clone phase is clearly shorter (for example at least 30% across
  repeated runs) and the steady-state suite is unchanged and green to the same degree.
- Adopt it only together with `file_copy_method = clone` when the gain appears only with reflinks;
  then the change depends on the filesystem and must be documented as such.
- Reject when the forced checkpoints make the clone phase slower on your storage.

## Risks

- `FILE_COPY` forces checkpoints before and after each copy; on slow-flush storage with `fsync = on`
  this may be slower than `WAL_LOG`.
- A pgsql-hackers report describes problems when a base backup overlaps `FILE_COPY` database
  creation (<https://www.postgresql.org/message-id/ZnmNOV2pm7b5N3zm%40nathan>). The replica
  container's entrypoint runs `pg_basebackup` on every start; do not start it while clones are
  rebuilding.
- Results from a Btrfs or ZFS host with `clone` do not transfer to the originating ext4 host, where
  `file_copy_method = clone` is unavailable.

## Rollback

Revert the one-line change in `rebuild_clone` (and `file_copy_method` if set). Existing clones stay
valid; the strategy affects only how future clones are created.

## References

- PostgreSQL documentation, `CREATE DATABASE` (`STRATEGY`) and `file_copy_method` (PostgreSQL 18).
- Aiven, "Why is database creation from templates slower for large databases in PostgreSQL 15?"
  (<https://aiven.io/community/forum/t/faq-why-is-database-creation-from-templates-slower-for-large-databases-in-postgresql-15/421>).
- pgsql-hackers, "use CREATE DATABASE STRATEGY = FILE_COPY in pg_upgrade"
  (<https://www.postgresql.org/message-id/Zmh1XZrMLGfyYdG-%40nathan>).
- boringsql, "Instant database clones" (<https://boringsql.com/posts/instant-database-clones/>).
