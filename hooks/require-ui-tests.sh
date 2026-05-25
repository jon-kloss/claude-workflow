#!/usr/bin/env bash
set -euo pipefail

# Block Edit/Write of @status(verified) on @layer(ui)/@layer(full-stack) specs
# unless a functional UI test file in the project references the spec slug.
#
# Enforces: every UI/GUI surface gets functional verification (not just visual
# fidelity inspection) before the spec can be marked verified.
#
# Test framework detection:
#   1. Override: $PROJECT_ROOT/.claude/ui-test-framework  (one of:
#      playwright | cypress | detox | vitest-browser | xcuitest | jest-rtl)
#   2. Auto-detect from project files (config files + package.json deps)
#   3. If nothing detected, block with instructions to install one.
#
# Test evidence requirement:
#   At least one test file in a recognized test dir (tests/, e2e/, cypress/e2e/,
#   __tests__/, specs/__tests__/, e2e-tests/, ui-tests/) that contains the spec
#   slug (or its first significant word) in either the filename or contents.
#
# Escape hatch: @ui-test-skip(reason) tag in spec content. Reason persists.
#
# Runs as PreToolUse hook on Edit/Write targeting specs/*.md files.

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HOOK_DIR/_common.sh"

if ! read -t 2 -r tool_use_json; then
    echo '{}'
    exit 0
fi

if ! json_valid "$tool_use_json"; then
    echo '{}'
    exit 0
fi

file_path=$(json_get "$tool_use_json" ".tool.input.file_path" "")
[ -z "$file_path" ] && file_path=$(json_get "$tool_use_json" ".tool_input.file_path" "")

if [ -z "$file_path" ]; then
    echo '{}'
    exit 0
fi

# Only spec files (skip system.md, arch.md)
if [[ "$file_path" != */specs/*.md ]]; then
    echo '{}'
    exit 0
fi

basename_file=$(basename "$file_path")
if [[ "$basename_file" == "system.md" ]] || [[ "$basename_file" == "arch.md" ]]; then
    echo '{}'
    exit 0
fi

new_content=$(json_get "$tool_use_json" ".tool.input.new_string" "")
[ -z "$new_content" ] && new_content=$(json_get "$tool_use_json" ".tool_input.new_string" "")
[ -z "$new_content" ] && new_content=$(json_get "$tool_use_json" ".tool.input.content" "")
[ -z "$new_content" ] && new_content=$(json_get "$tool_use_json" ".tool_input.content" "")

# Only trigger when @status(verified) is being written
if ! echo "$new_content" | grep -q "@status(verified)"; then
    echo '{}'
    exit 0
fi

# Build full spec view (existing file + new content) for layer/skip-tag checks
if [ -f "$file_path" ]; then
    spec_content="$(cat "$file_path" 2>/dev/null || echo "") $new_content"
else
    spec_content="$new_content"
fi

# Escape hatch: explicit @ui-test-skip(<reason>)
if echo "$spec_content" | grep -qE "@ui-test-skip\([^)]+\)"; then
    echo '{}'
    exit 0
fi

# Is this a UI-bearing spec?
# Primary signal: @layer(ui) or @layer(full-stack)
# Fallback: ## UI Design section present (for specs missing @layer)
is_ui_spec="no"
if echo "$spec_content" | grep -qE "@layer\((ui|full-stack)\)"; then
    is_ui_spec="yes"
elif echo "$spec_content" | grep -q "^## UI Design"; then
    is_ui_spec="yes"
fi

if [ "$is_ui_spec" != "yes" ]; then
    echo '{}'
    exit 0
fi

slug="${basename_file%.md}"
spec_dir="$(dirname "$file_path")"
project_root="$(dirname "$spec_dir")"

# ---------- Framework detection ----------
framework=""

# 1. Explicit override
if [ -f "$project_root/.claude/ui-test-framework" ]; then
    framework="$(tr -d '[:space:]' < "$project_root/.claude/ui-test-framework" 2>/dev/null || echo "")"
fi

# 2. Auto-detect (priority: e2e > component > native)
if [ -z "$framework" ]; then
    # Playwright
    if ls "$project_root"/playwright.config.{ts,js,mjs,cjs} 2>/dev/null | head -1 > /dev/null \
       || (test -f "$project_root/package.json" && grep -q '"@playwright/test"' "$project_root/package.json" 2>/dev/null); then
        framework="playwright"
    # Cypress
    elif ls "$project_root"/cypress.config.{ts,js,mjs,cjs} 2>/dev/null | head -1 > /dev/null \
         || (test -f "$project_root/package.json" && grep -q '"cypress"' "$project_root/package.json" 2>/dev/null); then
        framework="cypress"
    # Detox (React Native)
    elif test -f "$project_root/package.json" && grep -q '"detox"' "$project_root/package.json" 2>/dev/null; then
        framework="detox"
    # Vitest browser mode
    elif ls "$project_root"/vitest.config.{ts,js,mjs,cjs} 2>/dev/null | head -1 > /dev/null \
         && grep -qE 'browser:\s*\{' "$project_root"/vitest.config.* 2>/dev/null; then
        framework="vitest-browser"
    # Jest + react-testing-library
    elif test -f "$project_root/package.json" \
         && grep -q '"@testing-library/react"' "$project_root/package.json" 2>/dev/null \
         && grep -qE '"jest"|"vitest"' "$project_root/package.json" 2>/dev/null; then
        framework="jest-rtl"
    # XCUITest (native iOS)
    elif ls "$project_root"/*.xcodeproj 2>/dev/null | head -1 > /dev/null; then
        framework="xcuitest"
    fi
fi

if [ -z "$framework" ]; then
    cat <<EOF
{"error": "BLOCKED: specs/${slug}.md is UI-bearing (@layer ui/full-stack or ## UI Design section present) and is being marked @status(verified), but no UI test framework is installed in this project.\n\nInstall one and add a config file:\n  Playwright (web/Electron):  npx create-playwright \n  Cypress (web):              npm i -D cypress && npx cypress open \n  Detox (React Native):       https://wix.github.io/Detox/\n  Vitest browser mode:        https://vitest.dev/guide/browser/\n  Jest + react-testing-library: https://testing-library.com/docs/react-testing-library/intro/\n\nOr override detection by writing one of those keywords to .claude/ui-test-framework.\n\nTo skip this check (rare, document the reason), add to the spec:\n  @ui-test-skip(<reason>)"}
EOF
    exit 0
fi

# ---------- Test evidence ----------
# Look for a test file referencing this spec slug. Search common test dirs.
# Use the slug AND its first significant word (e.g. "user-auth" → also "user")
# as grep alternatives, to catch tests named more loosely.
first_word="$(echo "$slug" | cut -d- -f1)"

# Build search dirs (only those that exist)
search_dirs=()
for d in tests e2e cypress/e2e __tests__ e2e-tests ui-tests playwright-tests integration-tests src/__tests__ app/__tests__ test; do
    if [ -d "$project_root/$d" ]; then
        search_dirs+=("$project_root/$d")
    fi
done

# Also search ios/UITests/ for xcuitest
if [ "$framework" = "xcuitest" ]; then
    for d in UITests ios/UITests; do
        if [ -d "$project_root/$d" ]; then
            search_dirs+=("$project_root/$d")
        fi
    done
fi

if [ ${#search_dirs[@]} -eq 0 ]; then
    cat <<EOF
{"error": "BLOCKED: specs/${slug}.md is UI-bearing and being marked @status(verified), but no recognized test directory exists in this project.\n\nDetected framework: ${framework}\n\nCreate one of: tests/, e2e/, cypress/e2e/, __tests__/, e2e-tests/, ui-tests/, playwright-tests/, integration-tests/ (or UITests/ for xcuitest), then add a test file that references '${slug}'.\n\nTo skip (rare, document the reason): add @ui-test-skip(<reason>) to the spec."}
EOF
    exit 0
fi

# Search: filename contains slug OR file contents contain slug
# Use ripgrep if available, fall back to grep
match=""
search_pattern="${slug}\\|${first_word}"
for dir in "${search_dirs[@]}"; do
    # Filename match (any test-shaped file)
    if find "$dir" -type f \( -name "*${slug}*" -o -name "*${first_word}*" \) 2>/dev/null | grep -qE '\.(spec|test|e2e)\.(ts|tsx|js|jsx|mjs|cjs)$|\.swift$|\.kt$|\.java$|\.py$'; then
        match="filename"
        break
    fi
    # Contents match
    if grep -rIl --include='*.spec.ts' --include='*.spec.tsx' --include='*.spec.js' --include='*.spec.jsx' \
                 --include='*.test.ts' --include='*.test.tsx' --include='*.test.js' --include='*.test.jsx' \
                 --include='*.e2e.ts' --include='*.e2e.js' \
                 --include='*.swift' --include='*.kt' --include='*.java' --include='*.py' \
                 "$slug" "$dir" 2>/dev/null | head -1 | grep -q .; then
        match="contents"
        break
    fi
done

if [ -z "$match" ]; then
    cat <<EOF
{"error": "BLOCKED: specs/${slug}.md is UI-bearing and being marked @status(verified), but no functional UI test references this spec.\n\nDetected framework: ${framework}\nSearched: $(printf '%s ' "${search_dirs[@]#$project_root/}")\n\nAdd at least one test file that:\n  - Has '${slug}' in its filename (e.g. ${slug}.spec.ts), OR\n  - References '${slug}' in its test descriptions/imports\n\nThe test must exercise the actual UI surface (render the component, interact with it, assert behavior), not just unit-test internal helpers.\n\nReference: build/SKILL.md Step 3.3d (visual fidelity) and 4.1 (e2e for UI-bearing epics).\n\nTo skip this check (rare, document the reason): add to the spec:\n  @ui-test-skip(<concise reason>)"}
EOF
    exit 0
fi

# Test exists — allow
echo '{}'
