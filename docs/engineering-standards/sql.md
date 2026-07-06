# SQL / schema idioms

Load when the spec touches `*.sql` files or a `migrations/` directory. Pairs with `../engineering-standards.md` (§0–§4, §6). Coordinate with the data-architect handoff when one exists.

- **Parameterized queries ALWAYS — never build SQL by string concatenation/interpolation.** This is the #1 injection vector. Bind every user-supplied value. (Security-architect treats a concatenated query as CRITICAL.)
- **No `SELECT *` in application code.** Name the columns — it documents intent, survives schema changes, and avoids over-fetching.
- **Index the columns you filter/join/sort on;** don't index everything (writes pay for every index). Verify with `EXPLAIN`/`EXPLAIN ANALYZE` — a sequential scan on a large table in a hot query is a finding.
- **Migrations are reversible (a `down` exists) OR explicitly forward-only by design, stated in the migration header.** Each migration is idempotent where the engine allows. For large tables: add nullable column → backfill in batches → add constraint — never a blocking `ALTER` that locks a hot table.
- **Constraints in the database, not just the app:** `NOT NULL`, `FOREIGN KEY`, `UNIQUE`, `CHECK`. The DB is the last line of integrity defense.
- **Explicit transaction boundaries** around multi-statement invariants. Know your isolation level; keep transactions short to avoid lock contention.
- **Timestamps in UTC** (`timestamptz`); store money as integer minor units or `DECIMAL`, never float.
- **Naming:** consistent convention (snake_case tables/columns), singular vs plural per the project's existing choice (§0). Foreign keys named `<entity>_id`.
- **N+1 is a design defect, not a tuning task** — batch/join at design time.
