# Workflow Registry — Canonical Vocabulary

**This file is the single source of truth for the workflow's machine-level vocabulary.**
All skills, agents, hooks, and docs conform to this file; `tools/lint-consistency.sh`
enforces it. When a skill, agent prompt, hook, or doc disagrees with this file, the
other file is wrong and gets fixed — this file changes only by deliberate decision.

Decisions encoded here were made by the maintainer on 2026-07-04 (Phase 2 of the
EVALUATION-2026-07-04 fix plan; closes findings M1, M3, M4, M7, M8, M9, M13,
M14-data-step, H4-vocabulary). Phases 3–4 sweep hooks/skills/agents to conform.

---

## 1. Handoff filename grammar

Every role-agent handoff lives at:

```
specs/handoffs/step-<id>-<slug>-<role>[-fix-cycle-<N>].html
```

- `<id>` — one of the legal step ids in the table below. **The id is the PHASE-level
  number.** Sub-steps within the Step 3.3 verify pass all use `3.3` — the role
  disambiguates (`step-3.3-checkout-security-architect.html` vs
  `step-3.3-checkout-qa-engineer.html`).
- `<slug>` — the spec slug (matches a file in `specs/`), **except** step-4.1 and
  step-4.2, which use the epic id/slug (those steps are epic-scoped, not spec-scoped).
- `<role>` — an `agents/*.md` basename without the extension.
- `-fix-cycle-<N>` — optional suffix, spelled identically on BOTH sides of a fix
  cycle: implementers write `step-3.2-<slug>-<role>-fix-cycle-<N>.html`; reviewer
  re-verifies write `step-3.3-<slug>-<role>-fix-cycle-<N>.html`. The former
  `-cycle-N` and `-re-verify-N` spellings are retired.

### Legal `<id>` values

| `<id>` | Workflow step | Typical producing roles | `<slug>` source |
|---|---|---|---|
| `2` | /design Step 2 — Socratic questioning | product-owner | spec slug |
| `2.3` | /design Step 2.3 — game design (core loop) | game-designer | spec slug |
| `2.5` | /design Step 2.5 — decomposition | application-architect | spec slug |
| `2.7` | /design Step 2.7 — per-spec game design | level-designer, narrative-designer, systems-designer | spec slug |
| `2.85` | /design Step 2.85 — UI/UX design pipeline | uiux-designer, game-ui-designer | spec slug |
| `3.1` | /build Step 3.1 — investigation | data-architect (when `@touches-data`) | spec slug |
| `3.2` | /build Step 3.2 — implementation (TDD) | backend-engineer, frontend-engineer | spec slug |
| `3.3` | /build Step 3.3 — verify pass (all of 3.3a–3.3i) | security-architect, devops-architect, data-architect, qa-engineer, spec-sre-auditor | spec slug |
| `4.1` | /build Step 4.1 — epic-level cross-spec CUJ e2e | qa-engineer | **epic id/slug** |
| `4.2` | /build Step 4.2 — final verification | release-coordinator | **epic id/slug** |
| `4.5` | /design Step 4.5 — architecture documentation | application-architect, devops-architect | spec slug |

### Respec namespace

/respec handoffs do **not** use the `step-` prefix (that namespace belongs to
/design and /build). Two legal forms:

```
specs/handoffs/respec-3-<slug>-application-architect.html    (blast-radius analysis)
specs/handoffs/respec-4-<slug>-<role>.html                   (propagation, per downstream spec)
```

The former `step-3-<slug>-application-architect.html` and
`respec-<downstream>-<role>.html` spellings are retired (evaluation M13).

### Examples

```
specs/handoffs/step-2-user-auth-product-owner.html
specs/handoffs/step-3.3-checkout-security-architect.html
specs/handoffs/step-3.2-checkout-backend-engineer-fix-cycle-1.html
specs/handoffs/step-3.3-checkout-devops-architect-fix-cycle-1.html
specs/handoffs/step-4.2-workflow-8b2-release-coordinator.html
specs/handoffs/respec-3-user-auth-application-architect.html
specs/handoffs/respec-4-google-oauth-backend-engineer.html
```

---

## 2. Step IDs — the /build Step 3.3 verify pass

Canonical prose numbering (Phase 4 renames the existing SKILL.md sections to match).
Letters only, `a`–`i`; dotted sub-numbers (`3.3c.1`) and phantom letters are retired.

| Step | Name | Owner | Handoff file (id `3.3`) |
|---|---|---|---|
| 3.3a | test-suite | orchestrator (hyperpowers:test-runner) | none (test output) |
| 3.3b | test-effectiveness | hyperpowers:test-effectiveness-analyst | none (returned findings) |
| 3.3c | code-review | hyperpowers:code-reviewer | none (returned findings) |
| 3.3d | security-review | security-architect | `step-3.3-<slug>-security-architect.html` |
| 3.3e | devops-review | devops-architect | `step-3.3-<slug>-devops-architect.html` |
| 3.3f | data-review (when applicable) | data-architect | `step-3.3-<slug>-data-architect.html` |
| 3.3g | qa-verification (authoritative per-spec) | qa-engineer | `step-3.3-<slug>-qa-engineer.html` |
| 3.3h | sre-intent-audit | spec-sre-auditor | `step-3.3-<slug>-spec-sre-auditor.html` |
| 3.3i | fix-cycle | orchestrator dispatches implementers + re-verifies | `-fix-cycle-<N>` suffixed files per §1 |

### Old → new mapping (for the Phase 4 prose sweep)

| Old token | New token | Notes |
|---|---|---|
| 3.3c.1 (security) | 3.3d | dotted sub-numbering retired |
| 3.3c.2 (devops) | 3.3e | dotted sub-numbering retired |
| 3.3c.3 (data) | 3.3f | dotted sub-numbering retired |
| old 3.3d (qa per-spec verification) | 3.3g | qa keeps "authoritative" status; new letter |
| old 3.3g (SRE + intent audit) | 3.3h | |
| old 3.3h (fix-cycle) | 3.3i | |
| old "3.3e" / "3.3f" (layer coverage / API integration check) | **fold into 3.3g** | Phantom references — those sections were consolidated away (evaluation M4). Their intent (layer coverage, API integration / connectivity checking) lives in qa-engineer's 3.3g verification. Do not resurrect them as sections. |
| "Step 3.3.1" / "3.3.2" / "3.3.3" (agent frontmatter variants) | 3.3d / 3.3e / 3.3f | numeric-dot variants retired (evaluation M3) |

---

## 3. `data-step` meta value

The `<meta data-step>` value in a handoff head is **exactly the filename `<id>`**
(e.g. `"3.3"`, `"2.5"`, `"4.2"`). For respec handoffs it is `"respec-3"` or
`"respec-4"`. The `design.2.5-decomposition` format shown in earlier versions of
`docs/role-agent-handoff-schema.md` is retired; Phase 4 updates the schema doc.

---

## 4. Verdict vocabulary (`data-verdict`)

Every reviewer/auditor/coordinator handoff MUST carry `<meta data-verdict="...">` in
the document head. Legal values per role:

| Role(s) | Legal `data-verdict` values |
|---|---|
| security-architect, devops-architect, data-architect, qa-engineer, spec-sre-auditor | `PASS` \| `FAIL-CRITICAL` \| `FAIL-SPEC-DRIFT` |
| release-coordinator | `READY-TO-CLOSE` \| `READY-WITH-CAVEATS` \| `BLOCKED` |
| product-owner, application-architect, backend-engineer, frontend-engineer, uiux-designer, game-ui-designer, game-designer, level-designer, narrative-designer, systems-designer | no verdict required (producer/designer roles) |

Plaintext verdict lines (e.g. spec-sre-auditor's `Verdict:` line) map into
`data-verdict`: `FAIL (critical)` → `FAIL-CRITICAL`, `FAIL (spec-drift)` →
`FAIL-SPEC-DRIFT`. Hooks parse the meta attribute, never prose (evaluation M9, H4).

---

## 5. Severity vocabulary (`data-severity`)

```
critical | important | suggestion | spec-drift
```

`spec-drift` is a first-class severity (evaluation M9): the implementation is
internally fine but diverges from the spec's stated intent. `data-route-to` is
required on `critical` and `important`; `data-blocks-next-step="true"` is legal
only on `critical`.

---

## 6. Routing targets (`data-route-to`)

Canonical values — this table governs. The schema doc's prose claiming routing is
"always an implementer" is WRONG and will be deleted in Phase 4 (evaluation M8).

| `data-route-to` | When |
|---|---|
| `backend-engineer` | Server-side code, schema/migrations, queries, server-side security and performance, observability instrumentation |
| `frontend-engineer` | UI components, API wiring, visual fidelity, component accessibility, DOM-side security, client-side performance |
| `uiux-designer` | The mockup/design itself is wrong — anything requiring a return to /design-ui |
| `application-architect` | Architectural fit — seams, dependencies, separation of concerns. Triggers /respec |
| `devops-architect` | Infrastructure-as-code, deployment topology, runbooks, alerting. **Self-route allowed ONLY for IaC**, per the documented exception in `agents/devops-architect.md` |
| `product-owner` | Spec is wrong or ambiguous — scope, missing acceptance criteria, contradictions. Triggers /respec or a user question |

No other value is legal. Reviewers never route to another reviewer.

---

## 7. Override-tag registry

Every override tag, the hook that enforces it, and where it is documented. All
reasons are validated by `hooks/_validate_override_reason.py` (≥30 chars, ≥1
concrete reference, stop-phrase blocklist); passing overrides are appended to
`~/.claude/hooks/state/override-audit.log`.

| Tag | Enforcing hook | Documented in |
|---|---|---|
| `@verifier-skip(reason)` | `require-verifier-agents.sh` | build SKILL.md, README |
| `@handoff-skip(role: reason)` | `require-handoff-artifact.sh` | handoff schema doc, README |
| `@gate-skip(gate: reason)` | `claim-vs-call-audit.sh` | build SKILL.md, README |
| `@ui-test-skip(reason)` | `require-ui-tests.sh` | build SKILL.md, README |
| `@investigation-skip(reason)` | `require-investigation-findings.sh` | build SKILL.md |
| `@mount-skip(reason)` | `require-feature-mounted.sh` | build SKILL.md, README |
| `@integration-skip(reason)` | `require-feature-mounted.sh` | build SKILL.md, README |
| `@fix-cycle-skip(N: reason)` | `require-fix-cycle-handoff.sh` | build SKILL.md, README |
| `@handoff-author-skip(reason)` | `guard-handoff-owner.sh` | handoff schema doc, README |
| `@memory-update-skip(reason)` | `warn-agent-memory-not-updated.sh` | agent prompts, README |
| `@memory-allow-secret(reason)` | `guard-agent-memory-secrets.sh` | agent prompts, README |
| `@release-skip(reason)` in-spec + `RELEASE-SKIP:` bd comment | `require-release-handoff.sh` | release-coordinator.md — **the hook implements the in-spec tag in Phase 3** (evaluation H4) |
| `data-resolution-skip="reason"` (handoff attr) | `_validate_handoff.py` | handoff schema doc |

### Retired tags (banned — the linter flags them)

| Tag | Replacement |
|---|---|
| `@backend-only` | `@layer(api)` |
| `@api-only` | `@layer(api)` |
| bare `@cli` | `@layer(cli)` |
| bare `@infra` | `@layer(infra)` |

Phase 3 rewrites `require-design-ui.sh` to read `@layer(...)` (evaluation M1).

---

## 8. Spec tag vocabulary

| Tag | Meaning |
|---|---|
| `@status(draft\|approved\|implemented\|verified)` | Lifecycle state. Only these four values. |
| `@layer(api\|ui\|full-stack\|cli\|infra\|gameplay)` | Implementation surface. Exactly one per spec. |
| `@trivial` | Set at decomposition only. The single verification-scaling knob. |
| `@touches-data` | Spec touches persistent data → data-architect gates apply. |
| `@surface(game)` | Routes UI design to game-ui-designer instead of uiux-designer. |
| `@visual-pixel-diff` | Opts the spec into pixel-diff verification (structural diff is always on). |
| `@integration` | Marks the epic's integration spec (owns the `## Mount Map`). |
| `@mounts-in(slug)` | Feature spec's mount point in the integration spec. |
| `@depends-on(slug)` | Build-order dependency. |
| `@blocks(slug)` | Inverse dependency declaration. |
| `@parallel-risk(slug)` | Both specs touch the same files; do not build concurrently. |
| `@respec(YYYY-MM-DD)` | Spec was modified by /respec on this date. |
| `@deprecated` | Spec retired; kept for history. |

Free-form domain tags are allowed alongside these. Override tags are in §7.

---

## 9. Banned patterns

Enforced by `tools/lint-consistency.sh` rule R1. Each entry: pattern → why → what
to write instead.

| Banned pattern | Why | Write instead |
|---|---|---|
| Internal line-number citations matching `SKILL\.md:[0-9]` | Line cites rot on every edit; four hooks currently cite lines that no longer exist (evaluation M14) | Cite the section name: "see build SKILL.md, 'Step 3.3g: qa-verification'" |
| Step tokens matching `3\.3c\.[0-9]` | Retired dotted sub-numbering (evaluation M3) | The 3.3a–3.3i letters from §2 |
| Step tokens matching `Step 3\.3\.[0-9]` | Retired numeric variant of the same steps (evaluation M3) | The 3.3a–3.3i letters from §2 |
| `@api-only` / `@backend-only` / bare `@cli` / bare `@infra` | Abandoned tag vocabulary; taught by no skill (evaluation M1) | `@layer(api)`, `@layer(cli)`, `@layer(infra)` |
| `bd comment ` (singular) | Not a real bd subcommand — commands silently fail (evaluation H4) | `bd comments add` |

---

## 10. Change control

- Add a step id, verdict value, severity, routing target, tag, or override tag →
  edit this file first, then the consumers, then run `tools/lint-consistency.sh`.
- The linter derives its override-tag allowlist from §7 of this file at runtime.
- `docs/role-agent-handoff-schema.md` remains the authority for handoff *content*
  (required sections, meta attributes, resolution chains); this file is the
  authority for *vocabulary* (names, ids, filenames, legal values). Where the two
  currently disagree, this file wins; Phase 4 reconciles the schema doc.
