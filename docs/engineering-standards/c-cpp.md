# C / C++ idioms

Load when the spec touches a `CMakeLists.txt` / `Makefile` / `*.vcxproj` project. Pairs with `../engineering-standards.md` (§0–§4, §6).

## C++ (modern, C++17/20+)
- **RAII for every resource.** Ownership is expressed by type: `std::unique_ptr` (sole owner), `std::shared_ptr` (shared, only when ownership is genuinely shared), references/spans for non-owning access. **No raw `new`/`delete`** in application code; no owning raw pointers.
- **Rule of zero.** Prefer types that need no custom destructor/copy/move by composing RAII members. If you must write one special member, write/`=default`/`=delete` all five.
- **`const`-correctness everywhere.** `const` by default; `constexpr` for compile-time constants. Pass read-only params by `const&` (or by value for cheap types).
- **`std::optional` / `std::expected` (C++23) / error codes over exceptions in hot or embedded paths;** exceptions are fine for exceptional control flow in app code if the project uses them — be consistent with the codebase.
- **Prefer the algorithm to the hand loop** (`std::ranges::`), and `std::vector`/`std::array` over C arrays. `std::string_view`/`std::span` for non-owning views.
- **No macros for things the language can do** — `constexpr`, templates, `enum class` instead of `#define`. `enum class` for closed sets.
- **Avoid deep inheritance + virtual dispatch in hot paths** — data-oriented design for performance-critical/game code (struct-of-arrays, contiguous storage). Virtual calls are fine in cold control planes.

## C
- **Single owner per allocation; free on every path** (including error paths — `goto cleanup` is idiomatic). Pair every `malloc` with a clear `free` owner.
- **Check every return code.** Size buffers explicitly; prefer `snprintf` over `sprintf`, bounded string ops. No unchecked `strcpy`/`strcat`/`gets`.
- **`const` and `static` to scope tightly.** Opaque struct pointers for encapsulation.

## Tooling
- Warnings-as-errors (`-Wall -Wextra -Werror`), clang-tidy / cppcheck clean. ASan/UBSan in test builds. clang-format enforced.
