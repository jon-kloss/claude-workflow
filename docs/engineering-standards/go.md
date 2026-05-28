# Go idioms

Load when the spec touches a `go.mod` project. Pairs with `../engineering-standards.md` (§0–§4, §6).

- **Bar:** `gofmt`/`goimports` clean, `go vet` + `golangci-lint` clean.
- **Errors are values, handled explicitly.** `if err != nil { return fmt.Errorf("doing X: %w", err) }`. Wrap with `%w` to preserve the chain; check with `errors.Is`/`errors.As`. Never discard an error with `_` unless you've justified it in a comment.
- **Accept interfaces, return structs.** Define the interface where it's *consumed*, not where the implementation lives. Keep interfaces small (1–3 methods — `io.Reader` is the model).
- **Don't add an interface until there's a second implementation or a test seam that needs it.** Premature interfaces are the most common Go over-abstraction.
- **Zero values should be useful.** A struct usable without a constructor is good design. `sync.Mutex`'s zero value is a ready-to-use unlocked mutex — mirror that.
- **Concurrency: share memory by communicating.** Channels to pass ownership; `sync.Mutex` for simple shared state. Always know which goroutine owns a value. `context.Context` is the first parameter for anything cancellable/deadline-bound — propagate it, don't store it in a struct.
- **`defer` for cleanup** (close, unlock) right after acquiring the resource.
- **No panics for ordinary errors.** `panic` is for truly unrecoverable programmer bugs. Libraries return errors; they don't panic across API boundaries.
- **Table-driven tests** with subtests (`t.Run`). Standard `testing` package; reach for testify only if the project already uses it.
- **Composition over inheritance** (Go has no inheritance) — embed structs for reuse, but prefer explicit fields when embedding leaks methods you don't want.
- **Keep packages cohesive;** name them for what they provide (`http`, not `utils`). Avoid `util`/`common` grab-bags.
