---
agent: devops-architect
project-root: <abs path to project root>
last-updated: <ISO 8601 UTC at seconds precision, e.g. 2026-05-26T17:53:15Z — never T00:00:00Z>
last-commit-sha: <git HEAD at last write>
schema-version: 1
---

# devops-architect — project memory

## Summary

<1-2 paragraph orientation: deployment platform (Vercel / Fly / Railway / AWS / GCP / self-hosted), runtime (Node / Bun / Deno / containerized), database hosting, observability stack, CI/CD. 100-200 words.>

## Conventions (canonical — always observe)

- IaC tool: <Terraform | Pulumi | Vercel config | none — Vercel managed>
- Migration strategy: <forward-only | reversible — when required>
- Deployment: <main → prod via Vercel | manual promotion via gha-deploy.yml>
- Env vars source: <Vercel env | .env.local for dev | secret manager>
- Observability stack: <Sentry for errors | OTel + Honeycomb for traces | Vercel Analytics for RUM>
- Logging: structured JSON via pino; aggregated at <Logtail | Datadog | etc.>
- Health check: `/api/health` returns 200 + commit SHA

## Deployment topology

<text or inline-svg topology. Cite IaC files / config locations.>

```
[Vercel Edge] → [Next.js (Vercel Serverless)] → [Neon Postgres (us-east-2)]
                          │
                          ├─→ [Resend (transactional email)]
                          └─→ [Auth.js — embedded in Next.js process]

Trust boundary: VPC-private connection from Vercel Serverless → Neon Postgres.
```

Source: `vercel.json`, `next.config.ts`, `terraform/` (if applicable).

## Environments

| Env | URL | DB | Deploy trigger |
|---|---|---|---|
| local | http://localhost:3000 | local Postgres (docker-compose.yml) | `npm run dev` |
| preview | <project>.vercel.app/<branch> | Neon branch DB | every PR |
| prod | https://<project>.com | Neon primary | merge to main |

## SLOs (current)

- p95 read latency: <200ms (cited target — measured via Vercel Analytics)
- p95 write latency: <400ms
- Sign-in availability: ≥99.9% monthly
- RTO: 30 min via Neon PITR
- RPO: 1 min

## Observability instrumentation

<list of what's instrumented and where it surfaces.>

- Errors: Sentry (`SENTRY_DSN` env)
- Request logs: pino → Vercel logs → Logtail (`LOGTAIL_TOKEN` env)
- DB perf: `pg_stat_statements` enabled on Neon, slow-query log alerts
- Custom metrics: sign-in success rate, lockout engagement, post-deploy 5xx delta

## Alert thresholds

- Sign-in error rate >5% over 5m → PagerDuty
- Lockout-engagement >10/min sustained → PagerDuty (credential stuffing signal)
- Postgres connections >80% of pool → Slack #oncall
- 5xx rate >0.5% over 5m → PagerDuty

## Recent changes (rolling, last 5)

- <YYYY-MM-DD> — <spec or infra PR> — <operability change>

## Known issues / operability tech debt

- <list flagged-but-deferred items. Source, severity, fix path.>

## Pointers

<a id="pointer-rollback"></a>
### Rollback playbook
See `docs/operations/rollback.md`. Vercel: instant revert via dashboard or `vercel rollback`. DB migration rollback: if forward-only and prod has run the migration, the rollback path is a NEW forward migration that restores the prior state. NEVER `DROP TABLE` in a rollback.

<a id="pointer-runbook"></a>
### Oncall runbook
See `docs/operations/oncall.md`. Common pages + first response. Escalation tree.

<!--
ROLE-SPECIFIC NOTES (delete in production memory):
- This agent is ADVISORY for app-code findings (route to backend/frontend) but IMPLEMENTER for IaC.
- SLO targets are values to memorize; they drive what counts as a regression.
- Do NOT memorize real production hostnames or full IP ranges. Cite docs/operations/ pointers.
-->
