# C# / .NET idioms

Load when the spec touches a `*.csproj` / `*.sln` project. Pairs with `../engineering-standards.md` (§0–§4, §6).

- **Nullable reference types ON** (`<Nullable>enable</Nullable>`). Treat nullable warnings as errors; don't `!` (null-forgiving) your way past them.
- **`record` / `record struct` for immutable value types** (value equality + `with` expressions). Classes for entities with identity/behavior.
- **`async`/`await` all the way down — never `.Result` / `.Wait()`** (deadlock risk). `ConfigureAwait(false)` in library code. Return `Task`/`ValueTask`, accept `CancellationToken` for cancellable work and propagate it.
- **`IDisposable`/`IAsyncDisposable` + `using` declarations** for resources. Dispose what you own.
- **LINQ for transformation** where it reads clearly; watch for hidden multiple-enumeration (materialize with `.ToList()` once if iterated repeatedly).
- **Constructor injection via the built-in DI container.** Register against interfaces only where a seam genuinely varies (testing, multiple backends) — not reflexively (§3).
- **Pattern matching `switch` expressions + sealed hierarchies** for closed sets (your `match`).
- **Specific exceptions; don't catch `Exception` broadly.** Custom exception types at domain boundaries. Guard clauses (`ArgumentNullException.ThrowIfNull`) at public entry points.
- **`Span<T>`/`Memory<T>` for hot-path buffer work** to avoid allocations; don't reach for them in cold paths where they just add complexity.
- **Tests:** xUnit (or the project's existing framework); `[Theory]`/`[InlineData]` for table-driven cases. FluentAssertions if already in use.
- **Tooling:** `dotnet format` + analyzers clean; nullable + warnings-as-errors in CI.
