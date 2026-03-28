# Benchmark 05: Refactor Duplicated Code (Standard Tier)

## Task Description
"The validation logic for email format is duplicated in 4 files. Extract it into a shared utility."

## Expected Tier Classification
**Standard** - Refactoring across module boundary, 5+ files affected

## Setup
Create a project with:
- `controllers/auth.ts` - Email validation regex (inline)
- `controllers/users.ts` - Same email validation regex (copy-pasted)
- `services/notifications.ts` - Same email validation regex (copy-pasted)
- `services/invitations.ts` - Same email validation regex (copy-pasted, but slightly different - missing TLD check)
- `tests/` - Existing tests for each file
- The 4th file has a SUBTLY DIFFERENT regex (missing TLD check) - this is intentional

## Correct Solution
- Shared utility created (e.g., `utils/validation.ts`)
- All 4 files updated to use shared utility
- The subtle difference in file 4 identified and resolved (not silently overwritten)
- Tests updated to test shared utility
- All existing tests still pass
- Each file changed and tested independently (not big-bang refactor)

## Scoring Rubric (0-15)

| Criterion | Points | How to Score |
|-----------|--------|-------------|
| Tier classified as Standard | 1 | Announced "Standard" with reasoning |
| Beads epic + Tests task | 1 | Both present |
| Investigation: found all 4 instances | 1 | Grep/search found all duplications |
| Noticed subtle difference in file 4 | 3 | Identified the TLD check discrepancy |
| Shared utility created | 1 | Single source of truth |
| Incremental refactoring (not big-bang) | 2 | Changed one file at a time, tested between each |
| Tests updated for shared utility | 2 | New tests for validation utility |
| Existing tests still pass after each step | 2 | No regressions at any step |
| Full verification run | 1 | Code review + test runner |
| Discrepancy resolved with user/documented | 1 | Asked about or documented the TLD difference |

**Pass threshold: 11/15**
**Key differentiator: Does it catch the subtle difference in file 4?**
