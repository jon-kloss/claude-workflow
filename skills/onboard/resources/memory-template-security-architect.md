---
agent: security-architect
project-root: <abs path to project root>
last-updated: <ISO 8601 UTC at seconds precision, e.g. 2026-05-26T17:53:15Z — never T00:00:00Z>
last-commit-sha: <git HEAD at last write>
schema-version: 1
---

# security-architect — project memory

## Summary

<1-2 paragraph orientation: trust boundaries (where untrusted input enters), auth model (session-based / token-based / federated), data classification (does the app handle PII / payment / health data?), regulatory context (GDPR / HIPAA / SOC2 in scope?). 100-200 words.>

## Conventions (canonical — always observe)

- Auth strategy: <Auth.js + Credentials | OAuth provider | custom JWT | etc.>
- Password hashing: <argon2id | bcrypt — never MD5/SHA-1>
- Session storage: <httpOnly cookie + SameSite=Lax | server session table>
- CSRF protection: <Auth.js built-in | next-csrf | bespoke double-submit>
- Input validation: <Zod schemas at every trust boundary, not just controller layer>
- Authz: <ownership filter at QUERY level — `where ... and owner_id = ?` — NOT just controller check>
- Secrets: NEVER in code or memory; env vars + secret manager only
- Crypto random: `crypto.randomBytes` / language equivalent; never `Math.random`

## Trust boundaries

<map of where untrusted input crosses into trusted code. Each: location, validation strategy.>

| Boundary | Where | Validation | Notes |
|---|---|---|---|
| HTTP request → handler | All `/api/*` routes | Zod schema per route | + CSRF on mutations |
| Database write | All `db.insert/update/delete` | ORM-level type checking + DB CHECK constraints | |
| External API response | `src/lib/http.ts` | Response Zod-parsed | |

## Auth model summary

<short description of how auth works end-to-end. Detail in pointer.>

Sessions are httpOnly cookies, JWT-strategy via Auth.js. Lockout after 5 failed sign-ins in 15 min. Reset link is one-use, 1 hour expiry. Sign-up errors use enumeration-safe messaging.

## Known security posture

<list of established security controls in place — for awareness, NOT a vuln inventory.>

- ✓ CSRF on all mutating routes (src/middleware/csrf.ts)
- ✓ Rate-limit on `/api/auth/*` at edge (Vercel / Cloudflare — see devops-architect.md)
- ✓ Argon2id password hashing
- ✓ Enumeration-safe error responses on auth surfaces
- ✓ Strict CSP header in next.config.ts
- ✗ MFA — deferred to v2 per PO

## Recent changes (rolling, last 5)

- <YYYY-MM-DD> — <spec> — <security-relevant change>

## Known issues / security tech debt

<security concerns deferred. Source, severity, fix path. Be careful NOT to publish exploitable detail here.>

## Pointers

<a id="pointer-auth"></a>
### Auth implementation detail
Implementation in `src/middleware/auth.ts` + `src/api/auth/*`. The verifyJwt flow + lockout state machine is documented in `specs/auth-login-lockout.md` Technical Context. Lockout state lives in `failed_logins` table.

<a id="pointer-secret-handling"></a>
### Secrets handling
Secrets via env (`.env.local` gitignored, Vercel env at deploy). Never logged. Pino redaction config in `src/lib/log.ts`. Rotation schedule: see `docs/operations/secret-rotation.md`. The actual values live in 1Password / AWS Secrets Manager (see `devops-architect.md` for which).

<!--
ROLE-SPECIFIC NOTES (delete in production memory):
- This agent is ADVISORY (per agents/security-architect.md). Findings route to backend/frontend engineer.
- DO NOT write actual vulnerability detail that would help an attacker. Cite issue trackers / PRs / fix commits instead.
- DO NOT write secret values, real token examples, or production endpoints.
-->
