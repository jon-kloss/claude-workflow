# Benchmark 02: Add a Field to a Model (Quick Tier)

## Task Description
"Add a 'nickname' field to the User model"

## Expected Tier Classification
**Quick** - 1-2 files, <50 lines, add a field

## Setup
Create a project with:
- `models/user.ts` - User class with fields: id, name, email, createdAt
- `models/user.test.ts` - Existing tests for User model
- Existing pattern: all fields have validation (name: min 1 char, email: valid format)

## Correct Solution
- nickname field added to User model
- Validation follows existing pattern (e.g., max length, optional/required decision)
- Existing tests still pass
- New test for nickname field added
- Migration or schema update if applicable

## Scoring Rubric (0-10)

| Criterion | Points | How to Score |
|-----------|--------|-------------|
| Tier classified as Quick | 1 | Announced "Quick" with reasoning |
| Beads epic + Tests task | 1 | Both present |
| Read existing model before editing | 1 | Investigation: read user.ts first |
| Follows existing validation pattern | 2 | Validation matches name/email style |
| Tests written (TDD) | 2 | Test written before or alongside implementation |
| Existing tests still pass | 1 | No regressions |
| Full verification run | 2 | Code review + test runner |

**Pass threshold: 7/10**
**Key differentiator: Does the new field follow existing validation patterns?**
