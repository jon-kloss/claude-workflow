# Ruby idioms

Load when the spec touches a `Gemfile` / `*.gemspec` project. Pairs with `../engineering-standards.md` (§0–§4, §6).

- **Bar:** RuboCop clean (the project's `.rubocop.yml` is the local truth — §0).
- **Small methods, expressive names, blocks over manual iteration.** `map`/`select`/`reduce`/`each_with_object` over index loops. Tap into the rich Enumerable API.
- **Guard clauses for early return;** avoid deep nesting. `return unless valid?` at the top.
- **Duck typing — depend on the message, not the class.** Don't add `is_a?` checks where responding to a method is the real requirement.
- **Keyword arguments for anything beyond 1–2 params** (clarity at call sites) — not positional boolean flags.
- **Immutability where practical:** `freeze` constants; avoid mutating method arguments. Prefer returning new values.
- **Raise specific exception classes, rescue narrowly.** Never `rescue Exception` (catches signals); `rescue StandardError` or a specific subclass.
- **Metaprogramming is a scalpel, not a default.** `define_method`/`method_missing` only when it genuinely removes real duplication and stays debuggable. Readability beats cleverness.
- **Rails (if present):** fat-model-skinny-controller is dated — extract service objects / POROs for business logic. Scopes over inline queries. Avoid N+1 (`includes`). Strong params at the boundary.
- **Tests:** RSpec (or Minitest if that's the project's choice). Test behavior; avoid over-mocking — heavy stubbing is a design smell.
