# Bash / shell idioms

Load when the spec touches `*.sh` scripts. Pairs with `../engineering-standards.md` (§0–§4, §6).

- **`set -euo pipefail` at the top of every non-trivial bash script.** Fail on error, undefined variable, and broken pipe. (Hooks in this very workflow follow this.)
- **Quote every variable expansion: `"$var"`, `"${arr[@]}"`.** Unquoted expansions word-split and glob — the source of most shell bugs. ShellCheck flags these.
- **`[[ … ]]` over `[ … ]` in bash** (no word-splitting inside, supports `&&`/`=~`). `[ … ]` only when targeting POSIX `sh`.
- **ShellCheck clean.** Warnings are findings — they catch real quoting/portability bugs.
- **Prefer the right tool over shelling out in loops.** Don't `cat file | grep | awk | while read` when one `awk`/`rg` does it. Avoid `for f in $(ls)` — use globs (`for f in ./*`) or `find … -print0 | xargs -0`.
- **Check command existence + exit codes** before depending on output. `command -v foo >/dev/null || { echo "need foo" >&2; exit 1; }`.
- **`mktemp` for temp files + `trap '…' EXIT` to clean up.** Never hardcode `/tmp/myfile`.
- **`local` for function variables;** scripts aren't global-variable soup.
- **Errors and logs to stderr (`>&2`); stdout is for the script's actual output** (so it can be piped/captured). Especially true for anything that emits structured data.
- **No secrets in argv** (process table is world-readable) — pass via env or stdin.
- **Portability:** if it must run on macOS + Linux, beware `sed -i`, `readlink -f`, GNU-only flags. Test both or guard with feature detection.
