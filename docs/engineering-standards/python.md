# Python idioms

Load when the spec touches a `pyproject.toml` / `requirements.txt` / `setup.py` project. Pairs with `../engineering-standards.md` (§0–§4, §6).

- **Bar:** `ruff` (lint + format) and `mypy --strict` (or `pyright`) clean. Type hints on every public function signature.
- **EAFP over LBYL where idiomatic** — `try/except` around the operation beats pre-checking, *when* the exception path is genuinely exceptional. Catch specific exceptions, never bare `except:`.
- **Dataclasses / `pydantic` for structured data**, not bare dicts passed around. `@dataclass(frozen=True)` for value objects. Pydantic at external boundaries (parse/validate input).
- **Context managers (`with`) for resources** — files, locks, connections, transactions. Write `__enter__`/`__exit__` or use `contextlib.contextmanager` for custom scopes.
- **No mutable default arguments.** `def f(x=[])` is the classic bug — use `def f(x=None): x = x or []`.
- **Comprehensions over `map`/`filter`+`lambda`** for readability; but a plain loop when the comprehension gets nested/unreadable.
- **`pathlib.Path` over `os.path` string-munging.** `enumerate`/`zip` over index arithmetic.
- **Prefer pure functions + explicit dependencies over module-level mutable state.** If you need a singleton, a module-level instance is the Pythonic form — but inject it for testability.
- **Generators for large/streaming sequences** — don't materialize a giant list when you iterate once.
- **f-strings for formatting.** Never build SQL or shell strings by concatenation (injection — see sql.md / shell.md).
- **Tests:** `pytest`. Fixtures for setup; parametrize for table-driven cases. Assert on behavior, not implementation detail.
- **Async:** `asyncio` — don't block the event loop with sync I/O; use `asyncio.to_thread` for unavoidable blocking calls. Don't mix sync and async halfway.
