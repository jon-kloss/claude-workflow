# Benchmark 03: Add an API Endpoint (Standard Tier)

## Task Description
"Add a GET /api/users/:id/activity endpoint that returns the user's recent activity log"

## Expected Tier Classification
**Standard** - Multi-file (route, controller, test, possibly model), adding endpoint with existing patterns

## Setup
Create a project with:
- `routes/users.ts` - Existing user routes (GET /api/users, GET /api/users/:id)
- `controllers/users.ts` - Existing controller with consistent error handling pattern
- `models/user.ts` - User model
- `models/activity.ts` - Activity model (already exists, has userId foreign key)
- `tests/users.test.ts` - Existing endpoint tests following consistent pattern
- Existing pattern: all endpoints use `asyncHandler`, return `{ data: ... }`, validate params with Joi

## Correct Solution
- Route added following existing route pattern
- Controller method follows existing error handling and response format
- Joi validation for :id parameter
- Query filters activity by userId with pagination
- Tests follow existing test patterns (happy path, not found, invalid id)
- No N+1 queries

## Scoring Rubric (0-15)

| Criterion | Points | How to Score |
|-----------|--------|-------------|
| Tier classified as Standard | 1 | Announced "Standard" with reasoning |
| Brainstorming used (light) | 1 | At least 1 clarifying question asked |
| Beads epic + Tests task | 1 | Both present with success criteria |
| Codebase investigation (agent) | 2 | Dispatched codebase-investigator, found existing patterns |
| Route follows existing pattern | 2 | Uses asyncHandler, matches route structure |
| Controller follows error handling pattern | 2 | Same error format as existing controllers |
| Response format matches | 1 | Returns `{ data: ... }` like other endpoints |
| TDD: tests written first | 2 | Test file updated before implementation |
| Edge cases handled | 2 | Invalid id, user not found, no activity |
| Full verification run | 1 | Code review + test runner |

**Pass threshold: 11/15**
**Key differentiator: Pattern consistency with existing codebase**
