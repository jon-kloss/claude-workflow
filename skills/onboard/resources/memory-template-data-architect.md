---
agent: data-architect
project-root: <abs path to project root>
last-updated: <ISO 8601 UTC>
last-commit-sha: <git HEAD at last write>
schema-version: 1
---

# data-architect — project memory

## Summary

<1-2 paragraph orientation: database engine (Postgres / SQLite / etc.), ORM in use (Drizzle / Prisma / SQLAlchemy / etc.), migration tool, top-level schema shape. 100-200 words.>

## Conventions (canonical — always observe)

- Primary key strategy: <UUID v4 default gen_random_uuid() | bigserial | text | nanoid>
- Soft delete column: <deleted_at TIMESTAMPTZ NULL | hard delete only>
- Timestamps: <created_at NOT NULL DEFAULT now(), updated_at NOT NULL>
- Email normalization: <citext UNIQUE | lower(email) UNIQUE INDEX>
- FK cascade rule: <ON DELETE CASCADE | ON DELETE SET NULL — when each>
- Migration forward-only: <true | false>
- Index naming: <ix_<table>_<col> | <table>_<col>_idx>

## Schema overview (top-level)

<table or short list of top-level tables/collections. Drill into a Pointer for any non-obvious one.>

| Table | Purpose | Key columns | Spec | Pointer |
|---|---|---|---|---|
| users | account + auth | id, email (citext UNIQUE), created_at | data-model.md | [↓ users](#pointer-users) |
| lists | per-user lists | id, owner_id (FK users), name, sort_key | lists-crud.md | — |
| tasks | per-list tasks | id, list_id (FK lists), title, priority, due_at | tasks-crud.md | — |

## Index posture (current)

<list of non-obvious indexes — composite, partial, GiST, etc. Skip primary keys.>

- `tasks (list_id, sort_key)` — supports ordered task list view
- `tasks USING GIN (to_tsvector('english', title || ' ' || description))` — full-text search

## Migration history (recent)

<rolling list of last 5 migrations, with date + summary + rollback notes.>

- 2026-05-25 — `001_init.sql` — initial schema (users/lists/tasks/sessions). Reversible.
- ...

## Recent changes (rolling, last 5)

- <YYYY-MM-DD> — <spec> — <what data-layer changed>

## Known issues / data tech debt

<schema concerns flagged but deferred. Each: title, source, severity, remediation plan.>

## Pointers

<a id="pointer-users"></a>
### users table detail
See `src/db/schema.ts` for Drizzle definition. Note the **citext** type for email — Drizzle has no helper, so the migration uses raw SQL. See `backend-engineer.md` memory for the case-insensitive email lookup convention.

<!--
ROLE-SPECIFIC NOTES (delete in production memory):
- This agent is ADVISORY for fixes (per agents/data-architect.md). Findings route to backend-engineer.
- Never write schema migrations in memory — only document patterns and FK conventions.
- Index posture is high-leverage; an extra column added to a composite index has cascading query implications.
-->
