# Adaptive Developer Workflow for Claude Code

An enforced, adaptive developer workflow that classifies tasks into Quick/Standard/Complex tiers and chains 5 mandatory phases with deterministic quality gates.

## What It Does

Every task goes through:
1. **Classify** - Quick / Standard / Complex based on scope and complexity
2. **Plan** - Always creates beads epic with mandatory Tests task
3. **Investigate** - Read codebase before writing (depth scales with tier)
4. **Implement** - TDD always (review rigor scales with tier)
5. **Verify** - Full test suite + code review agent (NEVER scales down)

Planning depth scales with complexity. **Verification never does.**

## What's Included

```
.
├── install.sh                          # One-command installer
├── skills/
│   ├── workflow-orchestrator/SKILL.md  # Master workflow skill (657 lines)
│   └── workflow-retrospective/SKILL.md # Metrics analysis skill (395 lines)
├── hooks/
│   ├── track-reads.sh                  # Tracks Read/Grep/Glob calls
│   ├── block-unread-edits.sh           # Blocks edits on unread files
│   ├── clear-session-reads.sh          # Resets read tracking per session
│   ├── workflow-reminder.sh            # Reminds to use workflow on code changes
│   └── check-open-beads.sh             # Warns about open tasks on session end
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
- `jq` installed (`brew install jq` or `apt install jq`)

## Installation

```bash
git clone <this-repo> ~/.claude/workflow
cd ~/.claude/workflow
./install.sh
```

The installer:
- Copies skills to `~/.claude/skills/`
- Copies hooks to `~/.claude/hooks/`
- Merges hook config into `~/.claude/settings.json` (backs up first)
- Optionally disables the superpowers plugin (recommended)

## Usage

After installation, restart Claude Code (or `/clear`). Then:

1. **Start any task** - the workflow-orchestrator skill activates automatically
2. **Follow the phases** - Claude classifies the tier and chains the right skills
3. **After 3+ completed epics** - run `/workflow-retrospective` to analyze effectiveness
4. **Run benchmarks** - use `benchmarks/AB-TESTING-PROTOCOL.md` for quantitative comparison

## Design Principles

- **Verification never scales down** - Full suite + code review agent on every tier
- **Every epic has a Tests task** - Epic cannot close without it
- **Hooks enforce, CLAUDE.md advises** - Deterministic gates, not suggestions
- **Planning scales, verification doesn't** - Quick tasks get light planning but full verification
- **Investigate before writing** - Hook blocks edits on files you haven't read

## Uninstall

Restore the backed-up settings:
```bash
# Find your backup
ls ~/.claude/settings.json.backup.*
# Restore it
cp ~/.claude/settings.json.backup.YYYYMMDDHHMMSS ~/.claude/settings.json
# Remove skills and hooks
rm -rf ~/.claude/skills/workflow-orchestrator
rm -rf ~/.claude/skills/workflow-retrospective
rm -rf ~/.claude/hooks/
```
