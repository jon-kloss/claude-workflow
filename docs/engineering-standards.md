# Engineering Standards

Shared code-quality reference for the implementer agents (`backend-engineer`, `frontend-engineer`) and the code reviewers (`security-architect`, `spec-sre-auditor`, `hyperpowers:code-reviewer`). **Authors follow it; reviewers use it as a rubric.**

Read §0 first — it overrides everything else.

## §0 — Match the codebase before you match this doc

The Investigation Findings in the spec are the local truth. If the codebase already has an established pattern for what you're building, **use it** — even where this doc would suggest something else. Consistency within a codebase beats global "correctness." This doc is the fallback when there's no local precedent, and the rubric for when you're establishing a new one.

## §1 — Judgment over dogma

Good engineering is applying principles *where they earn their cost*, not applying all of them everywhere. The failure mode this doc most wants to prevent is **box-ticking** — naming SOLID or a design pattern to look rigorous while producing worse code.

**Priority order when rules conflict** (Kent Beck's rules of simple design):

1. **Passes the tests** — correctness first.
2. **Reveals intent** — a reader understands it without archaeology.
3. **No duplication of *knowledge*** — not no duplication of text (see below).
4. **Fewest elements** — no speculative classes, layers, or parameters.

When (2) and (3) conflict, **(2) wins.** A clear function with a little duplication beats a DRY tangle you have to decode.

**Three rules that override the instinct to abstract:**

- **Duplication is cheaper than the wrong abstraction (Sandi Metz).** Two or three similar blocks: leave them. Extract only when the *knowledge* is genuinely the same AND you have evidence they change together. A premature abstraction that later needs flags and conditionals to fit divergent callers is worse than copies.
- **Prefer deep modules (Ousterhout).** A module with a small interface and a rich implementation beats many shallow ones. Do NOT split a coherent unit into tiny single-method classes to satisfy "Single Responsibility" — that moves complexity into the wiring between them and raises the reader's cognitive load.
- **Validate at boundaries only.** User input, external APIs, deserialization edges get validation. Internal calls trust the type system and established invariants. Don't defensively check states that can't occur.

(Aligns with the global CLAUDE.md: "three similar lines is better than a premature abstraction"; "validate only at system boundaries.")

## §2 — Code-quality baseline (non-negotiable, every language)

- **Names reveal intent.** `replay_queued_pushes()` not `process()`. A name that needs a comment to explain it is the wrong name.
- **A function does one thing at one level of abstraction.** Mixing "orchestrate the steps" with "byte-fiddle the buffer" in one function is the smell. This is a level-of-abstraction rule, not a line-count rule.
- **Errors are handled at the boundary that can act on them.** Propagate with context until a layer that can decide. Don't swallow (`catch {}` / `let _ =` with no handling) and don't catch impossible states.
- **No dead code, no speculative generality.** No "might need this later" params, hooks, or config. If it isn't exercised by a test or a scenario, it shouldn't exist.
- **Comments explain WHY, never WHAT.** The code says what. A comment earns its place only for a non-obvious constraint, a workaround (with a ticket reference), or an invariant a reader would otherwise violate.

## §3 — SOLID, where it earns its cost

SOLID is context-dependent guidance, not law (cf. Dan North's **CUPID**, which reframes these as emergent properties — Composable, Unix-philosophy, Predictable, Idiomatic, Domain-focused — rather than rules). Apply per-principle:

| Principle | Earns its cost when | Is over-engineering when |
|---|---|---|
| **S**RP | A module has two reasons to change that genuinely evolve independently | You're splitting a cohesive unit into tiny classes; "responsibility" has no clear boundary (prefer deep modules, §1) |
| **O**CP | A stable extension point with multiple *known* variants (e.g. a provider trait with GitHub/GitLab/Bitbucket impls) | You're adding plugin machinery for a single implementation "in case" |
| **L**SP | You have a real subtype/trait hierarchy with multiple impls | (rarely over-applied — mostly a correctness constraint) |
| **I**SP | Consumers depend on a fat interface but use slivers of it | You're splitting interfaces nobody asked to be split |
| **D**IP | A volatile dependency (DB, network, clock) must be swappable for tests or backends | You're injecting things that will never have a second implementation |

The two highest-value in practice are **ISP** and **DIP** (decoupling growing systems). **SRP** is the most over-applied — when in doubt, prefer a deep module over more classes.

## §4 — Design patterns are vocabulary, not templates

GoF patterns are a shared language for *recognizing* structures, not code to install. Use one when it names a problem you actually have. Never reach for a pattern to look rigorous.

**Rust / systems code — patterns that are anti-idiomatic; use the idiom instead:**

- **Singleton** → module-level `static` / `OnceLock` / `Arc<Mutex<_>>`. Never a GoF `instance()`.
- **Abstract Factory** → trait objects (`dyn Trait`) or generics + a builder.
- **Visitor** → an `enum` + `match`. Exhaustiveness is the point.
- **Strategy** → a function pointer / closure / small trait, not a class hierarchy.
- General rule: reach for **enums + match** (closed sets), **traits + generics** (open extension), and **composition** before any inheritance-shaped pattern.

**`@layer(gameplay)` / hot-path code:** prefer **data-oriented design** — struct-of-arrays, flat data, systems over deep object graphs. Cache locality beats abstraction in inner loops. A trait-object virtual call per entity per frame is a smell.

**TypeScript / React:** the language has absorbed most patterns (modules = Singleton, decorators are native, iterators = `for..of`). Reach for composition and hooks, not GoF class structures.

## §5 — Language idioms (selective load — read ONLY your stack)

The example-backed language rules live in per-language sub-files under `docs/engineering-standards/`. **Do not load all of them.** Determine the language(s) your spec actually touches from the project's manifest, then read only the matching sub-file(s):

| Detect (project file) | Language | Sub-file to read |
|---|---|---|
| `Cargo.toml` | Rust | `~/.claude/workflow/docs/engineering-standards/rust.md` |
| `package.json` / `tsconfig.json` | TypeScript / JavaScript / React | `~/.claude/workflow/docs/engineering-standards/typescript-react.md` |
| `pyproject.toml` / `requirements.txt` / `setup.py` | Python | `~/.claude/workflow/docs/engineering-standards/python.md` |
| `go.mod` | Go | `~/.claude/workflow/docs/engineering-standards/go.md` |
| `pom.xml` / `build.gradle(.kts)` | Java / Kotlin | `~/.claude/workflow/docs/engineering-standards/jvm.md` |
| `*.csproj` / `*.sln` | C# / .NET | `~/.claude/workflow/docs/engineering-standards/csharp-dotnet.md` |
| `CMakeLists.txt` / `*.vcxproj` — or `Makefile` **plus** `.c`/`.cc`/`.cpp` sources (a Makefile alone is a generic build entry point, not a C signal) | C / C++ | `~/.claude/workflow/docs/engineering-standards/c-cpp.md` |
| `Package.swift` / `*.xcodeproj` | Swift | `~/.claude/workflow/docs/engineering-standards/swift.md` |
| `Gemfile` / `*.gemspec` | Ruby | `~/.claude/workflow/docs/engineering-standards/ruby.md` |
| `*.sql` / `migrations/` | SQL | `~/.claude/workflow/docs/engineering-standards/sql.md` |
| `*.sh` (shell scripts) | Bash / shell | `~/.claude/workflow/docs/engineering-standards/shell.md` |

A full-stack spec touches two stacks (e.g. Rust API + TS/React UI) — load both, nothing else. If your spec's language has no sub-file yet, fall back to §0–§4 + §6 and the codebase's existing idioms, and note the gap in `open-questions`.

## §6 — Anti-patterns to actively avoid

- **Box-ticking.** Naming a principle or pattern in a comment/handoff to signal rigor. The code is either clear or it isn't; the label adds nothing and often masks a worse design.
- **Abstraction astronaut / premature generalization.** Frameworks for one use case. Config for values that never change. Interfaces with one impl.
- **Wrong-abstraction DRY.** Merging code that *looks* similar but encodes different knowledge, then bolting on flags/conditionals when the callers diverge.
- **Shallow-layer proliferation.** Pass-through classes/functions that add a name and a stack frame but no behavior.
- **Cargo-culted patterns.** Porting a Java/C# OO pattern into Rust/TS where the language has a native idiom (§4).

---

**For reviewers:** treat §0–§6 as a rubric, not a hard gate (for now). A violation is a finding at the severity its real impact warrants — a box-ticked pattern that obscures logic is IMPORTANT; a missing `thiserror` conversion is usually a SUGGESTION. Route findings to the implementer via `data-route-to` per the handoff schema. Do not invent violations to look thorough — that's its own form of box-ticking.
