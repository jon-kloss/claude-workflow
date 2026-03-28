# Benchmark 06: Build a New Feature with External Integration (Complex Tier)

## Task Description
"Add webhook notifications - when a user completes an action, send a POST to their configured webhook URL"

## Expected Tier Classification
**Complex** - New feature, external integration (HTTP calls), cross-cutting concern

## Setup
Create a project with:
- `models/user.ts` - User model (no webhook field yet)
- `services/actions.ts` - Action completion service
- `config/` - Configuration directory with existing patterns
- `tests/` - Test suite with existing integration test patterns
- Existing pattern: services use dependency injection, errors logged to console

## Correct Solution
- Full brainstorming with questions about: retry policy, timeout, auth, payload format, failure handling
- Webhook URL field added to User model
- Webhook service created with: timeout, retry (exponential backoff), circuit breaker or similar
- Payload format documented
- Integration with action completion service
- Error handling: webhook failure does NOT block the user action
- Tests: unit tests for webhook service, integration test for full flow
- Edge cases: invalid URL, timeout, 5xx response, empty payload, user without webhook

## Scoring Rubric (0-20)

| Criterion | Points | How to Score |
|-----------|--------|-------------|
| Tier classified as Complex | 1 | Announced "Complex" with reasoning |
| Full brainstorming with Socratic questions | 2 | Asked about retry, timeout, auth, payload, failure handling |
| Research agents dispatched | 1 | Codebase-investigator + internet-researcher |
| Beads epic with immutable requirements | 2 | Requirements, anti-patterns, design rationale |
| Tests task in epic | 1 | Mandatory Tests task present |
| SRE refinement on tasks | 1 | At least first task SRE-refined |
| Webhook service with timeout | 1 | HTTP calls have configurable timeout |
| Retry logic (exponential backoff) | 2 | Not infinite retries, has backoff |
| Failure isolation (webhook failure != action failure) | 2 | User action succeeds even if webhook fails |
| TDD: tests before implementation | 2 | Failing tests written first |
| Edge cases handled | 2 | Invalid URL, timeout, 5xx, empty payload, no webhook configured |
| Full verification + code review per task | 2 | Code reviewer dispatched after each task |
| Epic closed with all criteria met | 1 | Proper close sequence |

**Pass threshold: 15/20**
**Key differentiator: Quality of brainstorming questions and failure isolation design**
