# TypeScript / JavaScript / React idioms

Load when the spec touches a `package.json` / `tsconfig.json` project. Pairs with the language-agnostic rules in `../engineering-standards.md` (§0–§4, §6).

## TypeScript
- **`strict` mode on.** No implicit `any`. If you reach for `any`, you've lost the type — use `unknown` + narrowing instead.
- **Type at the boundary, trust internally.** Parse/validate external data at the edge (zod or equivalent); once parsed, trust the types — don't re-validate internal calls.
- **Discriminated unions over boolean flags.** `type State = {kind:'loading'} | {kind:'error', msg:string} | {kind:'ok', data:T}` beats `{loading:bool, error?:string, data?:T}` — illegal states become unrepresentable.
- **Prefer `type` aliases + composition over `interface extends` hierarchies** unless you need declaration merging.
- **No enums for simple cases** — use string-literal unions (`'a' | 'b'`). Avoids the well-known TS `enum` runtime/erasure footguns.
- **`readonly` / `as const` for data that shouldn't mutate.** Avoid mutating shared objects.

## React
- **No `useEffect` for derived state or data transformation** — compute during render or `useMemo`. Effects synchronize with *external* systems only ([You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect)).
- **Composition over inheritance.** Custom hooks extract reusable stateful logic; components compose via children/props, not class hierarchies.
- **`memo` / `useCallback` / `useMemo` only when profiling shows a real re-render cost.** Over-memoization burns CPU on comparison checks and adds noise. Measure first.
- **Keys are stable identity, never array index** for dynamic lists.
- **Effects clean up.** Every subscription/listener/timer returns its teardown. Use `useSyncExternalStore` for subscribing to external stores rather than effect+setState.
- **Co-locate state with the component that owns it; lift only when shared.** Prop-drilling 2 levels is fine; 5 levels is the signal to reach for context or a store.
- **State management:** local → hooks; shared client state → Zustand/Jotai; server cache → TanStack Query. (Recoil is unmaintained — don't introduce it.) Don't stack >4 context providers — that's the signal for a store.
- **Accessibility is not optional:** semantic elements, `aria-*` where needed, keyboard paths, focus management. (Reviewed by qa-engineer.)

## Tooling
- ESLint + Prettier clean; `tsc --noEmit` passes. Lint warnings are findings.
