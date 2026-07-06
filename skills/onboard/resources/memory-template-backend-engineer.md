---
agent: backend-engineer
project-root: <abs path to project root>
last-updated: <ISO 8601 UTC at seconds precision, e.g. 2026-05-26T17:53:15Z — never T00:00:00Z>
last-commit-sha: <git HEAD at last write>
schema-version: 1
---

# backend-engineer — project memory

## Summary

<1-2 paragraph orientation: server framework (Next.js Route Handlers / Express / Fastify / Rails / Django / etc.), language, ORM, HTTP client used for outbound calls, test framework. 100-200 words.>

## Conventions (canonical — always observe)

- Error response shape: `{ error: string, code: string }` (src/lib/errors.ts)
- Validation: Zod schemas in `src/schemas/`; never trust request bodies directly
- DB access: only via `src/lib/db.ts` (Drizzle); no ad-hoc clients
- Auth check: `withAuth(handler)` wrapper from `src/middleware/auth.ts`
- Logging: `src/lib/log.ts` (pino); levels: error/warn/info/debug; never log raw secrets or PII
- Outbound HTTP: `src/lib/http.ts` with timeout default 5s, retry max 2

## Routes (current inventory)

<table of routes. One row per route. Keep ≤ 25 rows; drill via Pointers for grouped endpoints.>

| Method | Path | Handler file:line | Spec | Auth | Rate-limit |
|---|---|---|---|---|---|
| POST | /api/auth/login | src/api/auth/login/route.ts:14 | auth-login-lockout.md | public | edge 10/min/ip |
| POST | /api/auth/logout | src/api/auth/logout/route.ts:8 | auth-login-lockout.md | session | — |
| POST | /api/lists | src/api/lists/route.ts:22 | lists-crud.md | session | — |

## Middleware stack

<ordered list of middleware in the request path, with what each does. Source: src/middleware/ or framework config.>

1. CORS (src/middleware/cors.ts) — restricts to <origins>
2. CSRF (src/middleware/csrf.ts) — wraps all mutating routes
3. Auth (src/middleware/auth.ts) — sets req.user if session valid; throws 401 if route is gated
4. Logging (src/middleware/log.ts) — request-id, timing, log level

## Patterns to follow

<file-pattern references for common tasks. Cite file:line in the existing code.>

- New POST route: `src/api/<feature>/route.ts` exports an async `POST` function; uses `withAuth` if auth-required; validates body via Zod; returns Response with the standard error shape
- New table migration: `migrations/<NNN>_<name>.sql` with both up and down (down is comment-only if forward-only); update `src/db/schema.ts` Drizzle definitions

## Recent changes (rolling, last 5)

- <YYYY-MM-DD> — <spec> — <what backend changed>

## Known issues / tech debt

<server-side issues flagged but deferred. Each: title, source handoff/finding, severity, fix path.>

## Pointers

<a id="pointer-secrets"></a>
### Secrets handling
Secrets via `.env.local` (gitignored) + Vercel env at deploy. Never log. Scrubbed in error reporting via `src/lib/log.ts`'s `pinoRedact` config. The Auth.js secret rotation policy is documented at `docs/operations/secret-rotation.md`.

<a id="pointer-test-conventions"></a>
### Server-side test conventions
Vitest. Test files co-located: `src/<feature>/<file>.test.ts`. Integration tests at `tests/integration/`. DB tests use a per-suite ephemeral Postgres via `tests/lib/db-fixture.ts`.

<!--
ROLE-SPECIFIC NOTES (delete in production memory):
- This is one of the IMPLEMENTER memory files (with frontend-engineer). Used in fix-mode dispatches too.
- Routes section is the highest-leverage entry — keep it current as routes are added.
- Don't memorize endpoint payloads (those live in specs' Technical Context). Memorize the SHAPE conventions.
-->
