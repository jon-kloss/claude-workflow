---
agent: release-coordinator
project-root: <abs path to project root>
last-updated: <ISO 8601 UTC>
last-commit-sha: <git HEAD at last write>
schema-version: 1
---

# release-coordinator — project memory

## Summary

<1-2 paragraph orientation: deployment cadence, release tagging strategy, who owns production decisions, how rollbacks happen. 100-200 words.>

## Conventions (canonical — always observe)

- Tag strategy: <semver (v1.2.3) | calver (2026.05.26) | sha-based>
- Release notes: <CHANGELOG.md | GitHub Releases | both>
- Deploy gate: <green CI + manual promotion | auto-deploy on main | every PR previews>
- Production access: <Vercel dashboard | gha-deploy.yml | restricted to 2 humans>
- Rollback authority: any oncall engineer can revert; schema changes require devops-architect involvement

## Recent deployment history (rolling, last 10)

<list of recent prod releases. Each: date, tag/sha, summary, rollback status.>

- 2026-05-26 — v0.1.0 — initial deploy (greenfield) — no incidents
- ...

## Known incidents (post-mortem links)

<incidents that touched prod. Each: date, summary, link to post-mortem doc. Useful context for rollback decisions and known-bad patterns to avoid.>

## Recent changes (rolling, last 5)

- <YYYY-MM-DD> — <spec or epic> — <release-relevant change>

## Pointers

<a id="pointer-rollback"></a>
### Rollback playbook
See `devops-architect.md` memory and `docs/operations/rollback.md`. Quick reference: Vercel `vercel rollback` (instant) or dashboard click. Schema changes: read the migration's reversibility note; forward-only requires a NEW restoration migration, NOT a `DROP`.

<a id="pointer-changelog"></a>
### Release notes source
See `CHANGELOG.md` for human-readable history. Each entry references the epic-id from beads and the commit range.

<!--
ROLE-SPECIFIC NOTES (delete in production memory):
- This agent's memory is HISTORICAL more than predictive — it accumulates over time as releases ship.
- Deployment history grows; cap at 10 most recent. Older entries live in CHANGELOG.md.
- Incident list grows but never deletes entries — incidents matter as institutional memory.
-->
