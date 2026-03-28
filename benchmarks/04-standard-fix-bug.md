# Benchmark 04: Fix a Bug with Misleading Symptoms (Standard Tier)

## Task Description
"Users report that search results are empty when searching for items with special characters like '&' or '+'"

## Expected Tier Classification
**Standard** - Bug fix requiring investigation, likely multi-file

## Setup
Create a project with:
- `routes/search.ts` - Search endpoint that accepts query parameter `q`
- `services/search.ts` - Search service that queries database
- `tests/search.test.ts` - Existing tests (all pass, but none test special characters)
- The actual bug: query parameter is not URL-decoded before database query
- Red herring: the database query itself handles special chars fine - the issue is in the route layer

## Correct Solution
- Root cause identified: URL encoding issue in route layer, NOT database layer
- Fix applied to correct layer (route/middleware, not search service)
- Regression test added for special characters ('&', '+', '%', quotes)
- Existing tests still pass
- NOT a workaround (e.g., escaping chars in the search service)

## Scoring Rubric (0-15)

| Criterion | Points | How to Score |
|-----------|--------|-------------|
| Tier classified as Standard | 1 | Announced "Standard" with reasoning |
| Beads epic + Tests task | 1 | Both present |
| Investigation before fixing | 2 | Read search route + service, traced the data flow |
| Root cause identified (URL decoding, not DB) | 3 | Didn't fall for the red herring |
| Fix in correct layer (route, not service) | 2 | Changed URL decoding, not DB query |
| Regression test for special chars | 2 | Tests '&', '+', '%', quotes specifically |
| TDD: failing test first | 2 | Wrote test reproducing bug before fixing |
| Full verification run | 1 | Code review + test runner |
| Existing tests still pass | 1 | No regressions |

**Pass threshold: 11/15**
**Key differentiator: Does investigation find the real root cause, or does it fix the symptom?**
