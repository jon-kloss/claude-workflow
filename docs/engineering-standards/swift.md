# Swift idioms

Load when the spec touches a `Package.swift` / `*.xcodeproj` project. Pairs with `../engineering-standards.md` (§0–§4, §6).

- **Value types by default.** `struct`/`enum` for models; `class` only when you need reference semantics or identity. Embrace value semantics + immutability (`let` over `var`).
- **Optionals model absence — never force-unwrap (`!`) outside tests.** Use `if let`/`guard let`, `??`, optional chaining. `guard let … else { return }` at the top of a function for early exit.
- **`enum` with associated values for closed sets + exhaustive `switch`** (your `match`). Make illegal states unrepresentable.
- **Protocols + protocol extensions for shared behavior, not class inheritance.** Protocol-oriented design is the Swift idiom. Generics over `Any`.
- **Errors:** typed `throws` + `do/catch`, or `Result<Success, Failure>` for async-boundary/stored outcomes. Don't stringly-type errors — define an `Error` enum.
- **Concurrency: structured `async`/`await` + actors** for shared mutable state (don't hand-roll locks). `Task` for spawning; respect cancellation (`Task.checkCancellation()`). Mark UI-touching types `@MainActor`.
- **`some`/`any` deliberately** — `some` for opaque return types (static dispatch), `any` for existentials (dynamic, has a cost).
- **Avoid massive view controllers / massive views.** Extract logic into value types and view models; keep views declarative (SwiftUI) or thin (UIKit).
- **Tooling:** SwiftLint + SwiftFormat clean. XCTest (or Swift Testing); test behavior, not implementation.
