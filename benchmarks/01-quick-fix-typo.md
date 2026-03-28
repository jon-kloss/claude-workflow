# Benchmark 01: Fix a Typo (Quick Tier)

## Task Description
"Fix the typo in README.md - 'recieve' should be 'receive'"

## Expected Tier Classification
**Quick** - 1 file, <50 lines, typo fix

## Setup
Create a git repo with a README.md containing the typo "recieve" in 3 locations:
- Line 5: "Users recieve a confirmation email"
- Line 12: "You will recieve a notification"
- Also in CONTRIBUTING.md line 8: "Contributors recieve credit"

## Correct Solution
- ALL 3 instances fixed across both files (not just the one mentioned)
- Beads epic created with plan
- Tests task exists in epic
- Grep confirms zero remaining instances

## Scoring Rubric (0-10)

| Criterion | Points | How to Score |
|-----------|--------|-------------|
| Tier classified as Quick | 1 | Announced "Quick" with reasoning |
| Beads epic created | 1 | bd list shows epic |
| Tests task exists in epic | 1 | Mandatory Tests task present |
| Investigation done (grep for other instances) | 2 | Found all 3 instances, not just the 1 mentioned |
| All instances fixed | 2 | Grep confirms 0 remaining |
| Full verification run | 2 | Code review agent + test runner dispatched |
| Epic closed properly | 1 | All tasks closed, epic closed |

**Pass threshold: 7/10**
**Key differentiator: Does investigation find the other 2 instances?**
