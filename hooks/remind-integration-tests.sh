#!/usr/bin/env bash
set -euo pipefail

# Advisory hook: reminds about integration tests when committing source code
# without any integration test files staged.
#
# Language-agnostic — detects integration tests by directory/filename patterns
# common across ecosystems (tests/integration/, *_integration_test.*, e2e/, etc.).
#
# Non-blocking: injects additionalContext, never returns an error.
# Runs as PreToolUse hook on Bash commands.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

# Read tool use event from stdin
if ! read -t 2 -r tool_use_json; then
    echo '{}'
    exit 0
fi

# Validate JSON
if ! json_valid "$tool_use_json"; then
    echo '{}'
    exit 0
fi

# Extract the bash command (try multiple JSON shapes)
command=$(json_get "$tool_use_json" ".tool.input.command" "null")
if [ "$command" = "null" ] || [ -z "$command" ]; then
    command=$(json_get "$tool_use_json" ".tool_input.command" "null")
fi

if [ "$command" = "null" ] || [ -z "$command" ]; then
    echo '{}'
    exit 0
fi

# Only check git commit commands
if ! echo "$command" | grep -qE '\bgit\s+commit\b'; then
    echo '{}'
    exit 0
fi

# Get list of staged files
staged_files=$(git diff --cached --name-only 2>/dev/null || echo "")

if [ -z "$staged_files" ]; then
    echo '{}'
    exit 0
fi

# Check if any staged files are source code (not tests, configs, docs)
has_source=false
# Common source file extensions across languages
if echo "$staged_files" | grep -qE '\.(rs|go|py|js|ts|tsx|jsx|java|kt|rb|c|cpp|h|hpp|cs|swift|ex|exs|scala|php|sh|zig|lua|dart|vue|svelte)$'; then
    # Exclude files that are themselves test files
    non_test_source=$(echo "$staged_files" | grep -E '\.(rs|go|py|js|ts|tsx|jsx|java|kt|rb|c|cpp|h|hpp|cs|swift|ex|exs|scala|php|sh|zig|lua|dart|vue|svelte)$' | grep -ivE '(test|spec|_test\.|\.test\.|\.spec\.|tests/|__tests__|spec/)' || echo "")
    if [ -n "$non_test_source" ]; then
        has_source=true
    fi
fi

if [ "$has_source" = false ]; then
    echo '{}'
    exit 0
fi

# Check if any staged files look like integration tests
has_integration_tests=false

# Pattern 1: Files in integration/ or e2e/ directories
if echo "$staged_files" | grep -qiE '(integration|e2e|integ)/'; then
    has_integration_tests=true
fi

# Pattern 2: Files with "integration" in the filename
if echo "$staged_files" | grep -qiE '(integration_test|integration\.test|integrationtest|_integ_test|\.integ\.|_e2e\.|\.e2e\.)'; then
    has_integration_tests=true
fi

# Pattern 3: Files in common API test directories
if echo "$staged_files" | grep -qiE '(api[_-]?tests?/|functional[_-]?tests?/)'; then
    has_integration_tests=true
fi

# Pattern 4: Wire test files (HTTP API integration tests)
if echo "$staged_files" | grep -qiE '\.wire\.(yaml|yml)$'; then
    has_integration_tests=true
fi

if [ "$has_integration_tests" = true ]; then
    echo '{}'
    exit 0
fi

# Source code staged without integration tests — inject reminder
json_encode_context "
[INTEGRATION TESTS] Source code changes detected without integration tests.
Consider whether this change needs integration tests covering:
  - Cross-module/cross-crate boundaries
  - HTTP API endpoints (use wire or your framework's test client)
  - Database interactions
  - External service integrations
  - Message queue / event flows
  - CLI command end-to-end behavior
If this change is internal-only with no integration surface, this reminder can be safely ignored.
"
