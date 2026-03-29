# Adaptive Developer Workflow for Claude Code

An enforced, adaptive developer workflow that classifies tasks into Quick/Standard/Complex tiers and chains 6 mandatory phases with deterministic quality gates.

## What It Does

Every task goes through:
1. **Classify** - Quick / Standard / Complex based on scope and complexity
2. **Plan** - Brainstorm via AskUserQuestion (blocks until answered), then create beads epic with mandatory Tests task
3. **Investigate** - Read codebase before writing (depth scales with tier, only after brainstorming answers received)
4. **Implement** - TDD always (review rigor scales with tier)
5. **Verify** - Full test suite + code review + test-effectiveness-analyst agents (NEVER scales down)
6. **Close** - Close beads, update README if applicable, save learnings to memory

Planning depth scales with complexity. **Verification never does.**

## What's Included

```
.
├── install.sh                          # One-command installer (symlinks + backup)
├── uninstall.sh                        # Restores originals and removes symlinks
├── skills/
│   ├── workflow-orchestrator/SKILL.md  # Master workflow skill
│   └── workflow-retrospective/SKILL.md # Metrics analysis skill
├── hooks/
│   ├── beads-auto-resume.sh            # Surfaces in-progress/ready work on session start
│   ├── track-reads.sh                  # Tracks Read/Grep/Glob calls
│   ├── block-unread-edits.sh           # Blocks edits on unread files
│   ├── clear-session-reads.sh          # Resets read tracking per session
│   ├── require-bead-description.sh     # Enforces --description on bd create
│   ├── wwiwo.sh                        # "What Was I Working On?" — type wwiwo? to see work status
│   ├── workflow-reminder.sh            # Reminds to use workflow on code changes
│   └── check-open-beads.sh            # Warns about open tasks on session end
└── benchmarks/
    ├── 01-quick-fix-typo.md            # Quick tier benchmark
    ├── 02-quick-add-field.md           # Quick tier benchmark
    ├── 03-standard-add-endpoint.md     # Standard tier benchmark
    ├── 04-standard-fix-bug.md          # Standard tier benchmark
    ├── 05-standard-refactor.md         # Standard tier benchmark
    ├── 06-complex-new-feature.md       # Complex tier benchmark
    └── AB-TESTING-PROTOCOL.md          # A/B testing protocol
```

## Prerequisites

- [Claude Code](https://claude.ai/code) installed
- [hyperpowers](https://github.com/withzombies/hyperpowers) plugin enabled
- [beads](https://github.com/beads-project/beads) plugin enabled
- `python3` available (used by installer and beads-auto-resume hook)
- A bash-compatible shell (bash on macOS/Linux, Git Bash on Windows)

## Installation

```bash
git clone <this-repo> ~/.claude/workflow
cd ~/.claude/workflow
./install.sh
```

The installer:
- Links skills to `~/.claude/skills/` (edits in the repo are instantly live)
- Links hooks to `~/.claude/hooks/` (same - no manual sync needed)
- Merges hook config into `~/.claude/settings.json` (backs up first)
- Optionally disables the superpowers plugin (recommended)

On macOS/Linux, symlinks are used. On Windows, hard links are used (no
Developer Mode or Admin prompt required, but source and target must be on
the same drive).

## Usage

After installation, restart Claude Code (or `/clear`). Then:

1. **Start any task** - the workflow-orchestrator skill activates automatically
2. **Auto-resume** - on session start, you'll be shown any in-progress or ready beads work
3. **Type `wwiwo?`** - "What Was I Working On?" shows in-progress, ready, and recently closed work at any time
4. **Follow the phases** - Claude classifies the tier and chains the right skills
5. **Brainstorming blocks** - for Standard/Complex tiers, Claude asks questions via AskUserQuestion and waits for your answers before proceeding
6. **After 3+ completed epics** - run `/workflow-retrospective` to analyze effectiveness
7. **Run benchmarks** - use `benchmarks/AB-TESTING-PROTOCOL.md` for quantitative comparison

## Hooks

| Hook | Event | What It Does |
|------|-------|-------------|
| `beads-auto-resume.sh` | SessionStart | Checks for in-progress/ready beads work and presents it to the user |
| `clear-session-reads.sh` | SessionStart | Resets file read tracking so each session starts fresh |
| `block-unread-edits.sh` | PreToolUse (Edit/Write) | Blocks edits on files that haven't been read first |
| `require-bead-description.sh` | PreToolUse (Bash) | Enforces `--description` flag on `bd create` commands |
| `track-reads.sh` | PostToolUse (Read/Grep/Glob) | Tracks which files have been read (used by block-unread-edits) |
| `wwiwo.sh` | UserPromptSubmit (matcher: `wwiwo`) | "What Was I Working On?" — shows in-progress, ready, and recently closed work |
| `workflow-reminder.sh` | UserPromptSubmit | Reminds Claude to use the workflow-orchestrator for code changes |
| `check-open-beads.sh` | Stop | Warns about open beads tasks when the session ends |

## Workflow Retrospective

The **workflow-retrospective** skill provides a data-driven feedback loop for continuous improvement. It analyzes your completed work to find what's working and what needs tuning.

### What It Measures

| Metric | Target | What It Reveals |
|--------|--------|-----------------|
| First-pass verification rate | >80% | How often code passes verification without rework |
| Rework rate | <20% | How often tasks need fix-verify cycles |
| Error type distribution | - | Pattern mismatches vs edge cases vs integration failures |
| Phase effectiveness | - | Which phases catch errors (earlier = cheaper to fix) |
| Tier classification accuracy | <10% reclassified | Whether Quick/Standard/Complex heuristics are calibrated |

### How to Run

```
/workflow-retrospective
```

The skill runs a 5-step process:
1. **Gather** - Queries beads for closed epics, tasks, and verification failure comments
2. **Analyze** - Calculates metrics and identifies trends
3. **Report** - Presents a structured dashboard with tables
4. **Propose** - Recommends specific workflow adjustments based on the data
5. **Save** - Persists key findings to memory for cross-session awareness

### When to Run

- **After every epic** - quick metrics capture (5 min)
- **Weekly during active use** - full analysis with trend detection (15 min)
- **Monthly** - comprehensive cross-project trend analysis (30 min)

### Getting Started on a New Machine

The retrospective needs completed beads epics to analyze. After a fresh install:
1. Work through 3+ epics using the workflow-orchestrator
2. Run `/workflow-retrospective` for your first analysis
3. The skill handles limited data gracefully - it notes data limitations and tells you when to re-run

### Example Adjustments It Might Propose

- Pattern mismatches >30% of errors? **Strengthen Phase 2** - require codebase-investigator for all tiers
- Code review catches >50% of errors? **Earlier phases need strengthening** - errors should be caught sooner
- Quick tier tasks taking >2 hours? **Recalibrate tier heuristics** - raise the bar for Quick

All adjustments are **proposed, not auto-applied**. You review and approve before any workflow changes.

## Design Principles

- **Verification never scales down** - Full suite + code review agent on every tier
- **Brainstorming blocks on user answers** - AskUserQuestion tool required, no proceeding without answers
- **Every epic has a Tests task** - Epic cannot close without it
- **Hooks enforce, skills advise** - Deterministic gates, not suggestions
- **Planning scales, verification doesn't** - Quick tasks get light planning but full verification
- **Investigate before writing** - Hook blocks edits on files you haven't read
- **Links, not copies** - Skills and hooks are linked (symlinks on macOS/Linux, hard links on Windows) so repo edits are instantly live

## Uninstall

```bash
cd ~/.claude/workflow
./uninstall.sh
```

The uninstaller:
- Removes all skill and hook symlinks
- Restores any original files that were backed up during install (`.pre-workflow` suffix)
- Restores `settings.json` from its pre-workflow backup
- Leaves the repo itself untouched
