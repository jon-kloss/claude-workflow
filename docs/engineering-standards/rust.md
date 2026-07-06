# Rust idioms

Load when the spec touches a `Cargo.toml` project. Pairs with the language-agnostic rules in `../engineering-standards.md` (§0–§4, §6).

- **Bar:** [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/) + `cargo clippy` clean. Clippy warnings are findings, not noise.
- **Errors:** `thiserror` for library/typed errors a caller matches on; `anyhow` for application/opaque errors carrying context. Don't mix the two in one layer. Add context with `.context("...")` / `.with_context(|| ...)` at each boundary you cross.
- **No `unwrap()` / `expect()` in non-test library paths.** Use `?`, `if let`, `let … else`. `expect()` is acceptable only for a documented startup invariant (and the message states the invariant).
- **Closed set → `enum` + exhaustive `match`. Open extension → `trait`.** Don't reach for `dyn Trait` when an enum models the cases — exhaustiveness is free correctness.
- **Ownership models the design.** Prefer borrows (`&T`/`&mut T`) over cloning; reach for `Arc`/`Rc` only when shared ownership is real, not to dodge the borrow checker.
- **Builders over telescoping constructors or many-bool parameter lists.** `Foo::builder().a(x).b(y).build()` beats `Foo::new(x, y, true, false, None)`.
- **`Iterator` combinators over manual index loops** where they read more clearly; but a plain `for` loop is fine — don't chain ten adapters to avoid a loop.
- **`#[must_use]` on types/functions whose result must not be dropped.** Newtypes (`struct UserId(u64)`) over bare primitives for domain IDs.
- **Concurrency:** `Send`/`Sync` bounds say what's shareable; prefer message-passing (channels) over shared `Mutex` state where it fits. Hold locks for the shortest scope; never `.await` while holding a `std::sync::Mutex`.
- **`Zeroize` secrets; never log them** (project security convention — see security-architect memory).
- **Anti-idiomatic (see §4):** Singleton → `OnceLock`/`static`; AbstractFactory → traits/generics; Visitor → `enum`+`match`. No inheritance-shaped patterns.
- **`@layer(gameplay)` / hot paths:** data-oriented design — struct-of-arrays, flat data, systems over object graphs. Avoid a `dyn` virtual call per entity per frame.
- **Tests:** `#[cfg(test)] mod tests` colocated for units; `tests/` for integration. Descriptive snake_case test names that read as sentences.
