# Role-Agent Handoff Schema

Inter-agent and agent-to-human communication format for the workflow. Adapted from Simon Willison's "unreasonable effectiveness of HTML" — HTML's semantic vocabulary gives us rich, browser-auditable artifacts with just enough machine-checkable structure.

## File location

Every role-agent invocation produces exactly one handoff file at:

```
specs/handoffs/<step-id>-<spec-slug>-<role-slug>.html
```

Examples:

```
specs/handoffs/step-2-user-auth-product-owner.html
specs/handoffs/step-2.5-user-auth-application-architect.html
specs/handoffs/step-3.3-checkout-security-architect.html
```

The `step-id` is the dotted step number from the SKILL.md (e.g., `step-2.5`, `step-3.3d`). The `role-slug` matches the agent name without the `.md` extension.

## Required schema

Hooks parse only a small set of attributes. The rest of the document is the agent's free-form HTML.

### Document head (required)

```html
<!DOCTYPE html>
<html lang="en" data-handoff-version="1">
<head>
  <meta charset="utf-8">
  <meta data-from-role="application-architect">
  <meta data-spec-slug="user-auth">
  <meta data-step="design.2.5-decomposition">
  <meta data-produced-at="2026-05-25T14:32:11Z">
  <meta data-input-references="specs/handoffs/step-2-user-auth-product-owner.html">
  <title>Application Architect — Decomposition: user-auth</title>
  <style>/* inline minimal styling so the file opens standalone in a browser */</style>
</head>
```

Required `<meta>` attributes:

| Attribute | Type | Notes |
|---|---|---|
| `data-from-role` | role-slug | Matches an agent file in `agents/`. Hook verifies. |
| `data-spec-slug` | spec slug | The spec this handoff is about. Matches a file in `specs/`. |
| `data-step` | dotted-step-id | Identifies which workflow step produced this. |
| `data-produced-at` | ISO 8601 UTC | Timestamp. Hook cross-references against `session-agents.log`. |
| `data-input-references` | space-separated paths | The handoff files this agent read. Empty if no prior handoffs (e.g. first step). |

Required `<html>` attribute:

| Attribute | Value | Notes |
|---|---|---|
| `data-handoff-version` | `1` | Schema version. Bump when format changes. |

### Document body (required sections)

```html
<body>

  <section data-role="summary">
    <p>One-paragraph executive summary. The next agent reads this first.</p>
  </section>

  <section data-role="findings">
    <!-- Free-form. Use <table>, <dl>, <figure>+<svg>, <details>, <code>, <pre>, etc. -->
  </section>

  <section data-role="acceptance-criteria">
    <dl>
      <dt data-id="ac-1">Statement of what must be true for the next step to proceed</dt>
      <dd data-check="grep -c '@layer(' specs/*.md == 5">PASS</dd>
      ...
    </dl>
  </section>

  <section data-role="open-questions">
    <ul>
      <li>Question the next agent or the user must resolve.</li>
    </ul>
    <!-- Empty <ul> is fine when nothing is open. -->
  </section>

</body>
</html>
```

Required `<section data-role>` blocks (all four must be present, even if empty):

| `data-role` | Contents | Purpose |
|---|---|---|
| `summary` | One paragraph | Primer for the next reader. The downstream agent's prompt may receive only this section to save context. |
| `findings` | Free-form HTML | The actual deliverable. Where you do your job's work. |
| `acceptance-criteria` | `<dl>` with `<dt data-id>` + `<dd data-check>` | Machine-readable conditions for "this step is complete." Other hooks may grep these. |
| `open-questions` | `<ul>` of unresolved items | Surfaces gaps. Empty `<ul>` is OK. |

### Optional callouts

```html
<aside data-severity="critical" data-route-to="backend-engineer" data-blocks-next-step="true">
  <p>Critical issue — the next step must NOT proceed until this is resolved.</p>
  <p>Specifics: file:line, screenshot, repro steps, etc.</p>
</aside>

<aside data-severity="important" data-route-to="frontend-engineer">
  <p>Important but does not block.</p>
</aside>

<aside data-severity="suggestion">
  <p>Nice-to-have. No routing required.</p>
</aside>
```

`<aside data-severity>` values: `critical | important | suggestion`. The `data-blocks-next-step="true"` flag (only valid on `critical`) signals that the next role-agent dispatch must be paused for user intervention.

### Routing: who fixes what (`data-route-to`)

When a reviewer agent (QA, security-architect, devops-architect, data-architect, sre-auditor, code-reviewer) finds an issue, it does NOT fix the issue itself — the finder verifies and the implementer fixes. Each `<aside data-severity="critical|important">` and each row of a findings table SHOULD carry a `data-route-to="<role>"` attribute naming the agent responsible for the fix.

Canonical routing values:

| `data-route-to=` | When to use |
|---|---|
| `backend-engineer` | API code, server-side logic, schema/migrations, queries, security holes in server code, performance issues server-side, observability instrumentation (logs/metrics/traces in server code) |
| `frontend-engineer` | UI components, wiring to APIs, visual fidelity deviations, accessibility issues in components, XSS / CSRF / DOM-side security, client-side performance |
| `uiux-designer` | Mockup itself is wrong, gate-output didn't catch a design issue, register/brand drift, missing design-system tokens — anything that requires going back to `/design-ui` |
| `application-architect` | Architectural fit is wrong — seams, dependencies, separation of concerns. Triggers `/respec` for affected specs. |
| `devops-architect` | Infrastructure-as-code, deployment topology, runbook, alerting — anything outside the application code |
| `product-owner` | Spec is wrong or ambiguous — scope creep, missing acceptance criteria, contradictory requirements. Triggers `/respec` or a user clarifying question. |

Architect agents (security, devops, data) and quality agents (QA, sre-auditor) are **advisory** — they identify issues but always `data-route-to=` an implementer (`backend-engineer`, `frontend-engineer`, or `uiux-designer`). If you find yourself wanting to route to `security-architect`, route to whichever engineer owns the code containing the security hole and include the architect's analysis in the finding body.

`data-route-to` is optional on `data-severity="suggestion"` (those don't trigger a fix dispatch). It IS required on `data-severity="critical"` and `data-severity="important"` — without it, the orchestrator can't dispatch a fix.

### Findings tables that route

Rows of a findings `<table>` MAY include a `data-route-to` cell. If your findings are in a `<dl>`, attach `data-route-to` to the `<dd>`. Example:

```html
<table>
  <thead><tr><th>Issue</th><th>file:line</th><th>Severity</th><th>Route to</th></tr></thead>
  <tbody>
    <tr><td>Missing CSRF token on PATCH</td><td>src/api/preferences/theme/route.ts:24</td><td>CRITICAL</td><td data-route-to="backend-engineer">backend-engineer</td></tr>
    <tr><td>Toggle hover state missing</td><td>src/components/ThemeToggle.tsx:12</td><td>IMPORTANT</td><td data-route-to="frontend-engineer">frontend-engineer</td></tr>
  </tbody>
</table>
```

The orchestrator reads these to build the fix-cycle dispatch list.

## What goes in `findings`

Free-form. Use whichever HTML elements best convey the work:

- `<table>` — for matrices (e.g., decomposition map, scenario→test mapping)
- `<dl>` — for definitions and pair lists
- `<figure>` + inline `<svg>` — for architecture diagrams, sequence diagrams (replaces draw.io for handoffs)
- `<details><summary>` — collapsible long-form content
- `<pre><code class="language-X">` — code or diff snippets
- `<ol>` — ordered procedure
- `<a href="path/to/file.ts#L42">` — link to file+line. Hooks can grep these to verify references are real.

Keep it readable. The user opens these in a browser to audit. If the rendered HTML doesn't make immediate sense to a teammate, the structure is wrong.

## Examples

### Example 1 — Product Owner (Step 2)

```html
<!DOCTYPE html>
<html lang="en" data-handoff-version="1">
<head>
  <meta charset="utf-8">
  <meta data-from-role="product-owner">
  <meta data-spec-slug="user-auth">
  <meta data-step="design.2-socratic">
  <meta data-produced-at="2026-05-25T14:00:00Z">
  <meta data-input-references="">
  <title>Product Owner — Socratic: user-auth</title>
  <style>body{font:14px/1.6 system-ui;max-width:50rem;margin:2rem auto;padding:0 1rem}h2{border-bottom:1px solid #ddd}aside[data-severity=critical]{border-left:4px solid #c00;padding:0.5rem 1rem;background:#fee}</style>
</head>
<body>
  <h1>User Auth — Requirements (Product Owner)</h1>

  <section data-role="summary">
    <p>Users need email + password authentication with optional Google OAuth, supporting password reset and account lockout after 5 failed attempts. Mobile and web. No SSO for v1.</p>
  </section>

  <section data-role="findings">
    <h2>Resolved questions</h2>
    <dl>
      <dt>What identifies a user?</dt>
      <dd>Email (case-insensitive, unique). User-chosen display name separately.</dd>
      <dt>Password requirements?</dt>
      <dd>Min 12 chars, no other constraints. Rely on length + breached-password check via HIBP API.</dd>
      <dt>Session model?</dt>
      <dd>JWT in httpOnly cookie. 7-day refresh. Sliding expiration not requested.</dd>
      <dt>Account lockout?</dt>
      <dd>5 failed attempts within 15 minutes → 30-min lockout. Email notification on lockout.</dd>
    </dl>

    <h2>Edge cases user surfaced</h2>
    <ul>
      <li>User changes email while logged in: re-prompt for password, invalidate other sessions.</li>
      <li>User deletes account: keep email reserved 30 days, then release.</li>
    </ul>
  </section>

  <section data-role="acceptance-criteria">
    <dl>
      <dt data-id="ac-po-1">Decomposition produces one spec per authentication flow</dt>
      <dd data-check="manual review of application-architect handoff">pending</dd>
      <dt data-id="ac-po-2">Google OAuth is a separate spec marked @depends-on(user-auth-email-password)</dt>
      <dd data-check="grep -l '@depends-on(user-auth-email-password)' specs/*.md returns google-oauth.md">pending</dd>
    </dl>
  </section>

  <section data-role="open-questions">
    <ul>
      <li>Should we offer passkey/WebAuthn in v1 or defer? — Deferred per user.</li>
    </ul>
  </section>
</body>
</html>
```

### Example 2 — Application Architect (Step 2.5, references prior handoff)

```html
<!DOCTYPE html>
<html lang="en" data-handoff-version="1">
<head>
  <meta charset="utf-8">
  <meta data-from-role="application-architect">
  <meta data-spec-slug="user-auth">
  <meta data-step="design.2.5-decomposition">
  <meta data-produced-at="2026-05-25T14:15:00Z">
  <meta data-input-references="specs/handoffs/step-2-user-auth-product-owner.html">
  <title>Application Architect — Decomposition: user-auth</title>
  <style>body{font:14px/1.6 system-ui;max-width:60rem;margin:2rem auto;padding:0 1rem}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ddd;padding:6px 10px;text-align:left}code{background:#f4f4f4;padding:1px 4px;border-radius:3px}</style>
</head>
<body>
  <h1>User Auth — Decomposition (Application Architect)</h1>

  <section data-role="summary">
    <p>Three specs: <code>user-data-model</code> (@layer api, foundational), <code>user-auth-email-password</code> (@layer full-stack, depends on data model), <code>user-auth-google-oauth</code> (@layer full-stack, depends on email-password for session model). Parallel-risk noted between email-password and oauth — both modify auth-routes.ts.</p>
  </section>

  <section data-role="findings">
    <h2>Decomposition map</h2>
    <table>
      <thead><tr><th>Spec slug</th><th>@layer</th><th>@depends-on</th><th>@parallel-risk</th><th>Why this seam</th></tr></thead>
      <tbody>
        <tr><td>user-data-model</td><td>api</td><td>—</td><td>—</td><td>Schema is a clean boundary; multiple auth flows will consume it</td></tr>
        <tr><td>user-auth-email-password</td><td>full-stack</td><td>user-data-model</td><td>—</td><td>Independent test surface (login form + POST /auth/login)</td></tr>
        <tr><td>user-auth-google-oauth</td><td>full-stack</td><td>user-data-model, user-auth-email-password</td><td>user-auth-email-password (both edit src/routes/auth.ts)</td><td>OAuth flow has its own scenarios but shares the session-issuing code path</td></tr>
      </tbody>
    </table>

    <h2>Seams considered and rejected</h2>
    <details>
      <summary>Split session management into its own spec?</summary>
      <p>Considered <code>session-issuance</code> as a fourth spec. Rejected — the session model is implementation detail of "log in succeeds", not a separate user-visible behavior. Embedded in user-auth-email-password.</p>
    </details>
  </section>

  <section data-role="acceptance-criteria">
    <dl>
      <dt data-id="ac-aa-1">Three spec files exist in specs/</dt>
      <dd data-check="ls specs/user-data-model.md specs/user-auth-email-password.md specs/user-auth-google-oauth.md">pending</dd>
      <dt data-id="ac-aa-2">Each spec has exactly one @layer tag</dt>
      <dd data-check="for s in user-data-model user-auth-email-password user-auth-google-oauth; do test 1 -eq $(grep -c '@layer(' specs/$s.md); done">pending</dd>
      <dt data-id="ac-aa-3">Dependency graph has no cycles</dt>
      <dd data-check="application-architect verified by inspection">PASS</dd>
    </dl>
  </section>

  <section data-role="open-questions">
    <ul></ul>
  </section>
</body>
</html>
```

## What hooks check

`hooks/require-handoff-artifact.sh` validates, at minimum:

1. The file at `specs/handoffs/<step>-<slug>-<role>.html` exists.
2. The `<html>` element has `data-handoff-version="1"`.
3. The five required `<meta data-*>` attributes are present and non-empty.
4. The four required `<section data-role>` blocks are present.
5. The `data-spec-slug` value matches the slug in the filename.
6. Every path in `data-input-references` exists on disk.
7. The HTML is well-formed enough to parse (gracefully degrades — minor sloppiness is tolerated; broken DOM is not).

Optional checks the hook MAY apply:

- Cross-reference `data-produced-at` against `session-agents.log` for that role.
- Walk `<a href>` links and verify file paths exist.
- Reject if any `<aside data-severity="critical" data-blocks-next-step="true">` is present unresolved.

## Tradeoffs

- **More verbose than JSON for pure data.** Acceptable. The receiver is an LLM with a large context window, and the human-audit story outweighs verbosity.
- **LLMs occasionally produce malformed HTML.** The hook validates structure and rejects malformed handoffs with a clear retry message.
- **Larger downstream context.** Mitigation: downstream prompts can request only the `data-role="summary"` and `data-role="acceptance-criteria"` sections (5-15 lines) instead of the full file.

## Versioning

Bump `data-handoff-version` when the required schema changes. The hook supports the current version only; old handoff files become read-only artifacts of historical sessions.
