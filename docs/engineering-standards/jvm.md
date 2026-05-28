# Java / Kotlin idioms

Load when the spec touches a `pom.xml` / `build.gradle(.kts)` project. Pairs with `../engineering-standards.md` (§0–§4, §6).

## Shared (JVM)
- **Immutability by default.** Final fields, unmodifiable collections, no setters unless the domain needs mutation.
- **Constructor injection over field injection / service locators.** Dependencies explicit and final. (This is DIP done right — but only inject what truly varies; see §3.)
- **Fail fast at boundaries; don't return `null` from public APIs.** Java: `Optional<T>` for "may be absent" returns (not for fields/params). Kotlin: the type system already encodes nullability — use it.
- **Prefer streams/sequences for transformation** where they read clearly; a plain loop when they don't.

## Java
- **`record` for value/DTO types** (immutable, equals/hashCode/toString free). Sealed classes/interfaces for closed hierarchies + pattern-matching `switch`.
- **Specific exceptions, never swallow.** Don't catch `Exception` broadly. Checked exceptions wrap into domain exceptions at boundaries.
- **`var` for obvious local types; explicit for public signatures.**

## Kotlin
- **Null-safety is the headline feature** — avoid `!!`. Use `?.`, `?:`, `requireNotNull`/`checkNotNull` with messages at boundaries.
- **`data class` for value types; `sealed class`/`sealed interface` + `when` for closed sets** (exhaustive `when` is your `match`).
- **Extension functions over util classes.** Scope functions (`let`/`apply`/`also`/`run`) for clarity, not cleverness.
- **Coroutines for async** — structured concurrency (`coroutineScope`), pass `CoroutineContext`, don't leak `GlobalScope`.
- **Prefer `val` over `var`; immutable collections (`listOf`) over mutable** unless mutation is the point.

## Tooling
- ktlint/detekt (Kotlin) or Checkstyle/SpotBugs (Java) clean. JUnit 5; AssertJ/Truth for fluent assertions.
