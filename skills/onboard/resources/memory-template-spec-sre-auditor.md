---
agent: spec-sre-auditor
project-root: <abs path to project root>
last-updated: <ISO 8601 UTC>
last-commit-sha: <git HEAD at last write>
schema-version: 1
---

# spec-sre-auditor — project memory

## Summary

<1-2 paragraph orientation: this codebase's recurring intent-failure patterns, the SRE concerns most often relevant here (which axes — latency, observability, idempotency, recovery — matter most for this product). 100-200 words.>

## Recurring intent-failure patterns (this codebase)

<accumulated patterns where mechanical reviewers pass but intent isn't delivered. Each: pattern, source spec(s)/finding(s), recommendation for future audits.>

- **next-themes localStorage override on hydration** (dark-mode.md, F-INTENT-1) — `next-themes` bootstrap can override SSR-resolved theme post-hydration, producing the very FOUC the spec forbids. Future audits: always check the hydration path on theme/preference features.
- **Rapid-toggle last-write-wins gap** (dark-mode.md, F-INTENT-2) — multiple clicks → multiple concurrent PATCHes → DB/DOM divergence. Future audits: any "save on click" UX needs request coalescing or version-column optimistic concurrency.

## SRE checklist additions (codebase-specific)

<concerns that should always be in audit, ABOVE the generic SRE checklist.>

- For any auth-touching spec: verify lockout state is consulted BEFORE password verification (failed_logins.attempt_count read before bcrypt compare)
- For any UI persistence spec: verify SSR cookie + DB row are both updated atomically; no race between server-write and client-bootstrap
- For any list/task spec: verify ownership filter is at QUERY layer (where ... and owner_id = ?), not controller layer
- For any drag-reorder spec: verify sort_key generation is collision-resistant (LexoRank or fractional indexing, NOT integer position)

## Past audit verdicts (rolling, last 10)

<rolling list of audits with verdict. Each: date, spec, verdict, summary.>

- 2026-05-25 — dark-mode.md — FAIL (critical) → fix cycle resolved → PASS — caught 2 intent bugs missed by mechanical reviewers

## Recent changes (rolling, last 5)

- <YYYY-MM-DD> — <spec> — <audit-relevant context>

## Pointers

<a id="pointer-sre-skill"></a>
### Full SRE checklist
See `agents/spec-sre-auditor.md` for the canonical full prompt. This memory holds CODEBASE-SPECIFIC additions to that checklist, not duplicates.

<!--
ROLE-SPECIFIC NOTES (delete in production memory):
- This agent's memory is the SECOND-RUN-AND-LATER advantage. Bootstrap seeding is DEFERRED in /onboard;
  this memory file is created/seeded on the first real spec-sre-auditor dispatch (after first /build's Step 3.3g).
- Recurring patterns section is the highest-leverage entry — it catches issues that "should have been obvious."
- Never duplicate the generic SRE checklist that lives in agents/spec-sre-auditor.md.
-->
