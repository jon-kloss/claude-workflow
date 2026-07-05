#!/usr/bin/env bash
set -euo pipefail

# Block Edit/Write of @status(verified) on a @layer(ui)/@layer(full-stack)
# feature spec unless that feature is actually assembled into the product:
#   - it is listed in an integration spec's Mount Map, OR
#   - it is imported by the application source (best-effort code check).
#
# Why this exists (SquashBuckler dogfood, 2026-05-31): ~40 UI features each
# reached @status(verified) on their own unit tests + per-feature visual
# fidelity while NEVER being mounted into a running app. The app shell
# (app-window-layout.md) was retrofitted afterwards under an "app-shell
# umbrella" slug — a rescue, not a plan. "Verified" verified demo cards.
# This hook makes "mounted in the product" part of a UI feature's definition
# of done, so the integration spec must exist and own every feature UP FRONT.
#
# Scope (matches /design Step 2.5 rule): only fires when the epic has >=2
# user-facing specs (@layer(ui|full-stack)). Single-UI-feature epics, CLI-only,
# API-only, library, and infra-only epics are exempt automatically — no skip
# tag needed.
#
# The integration spec is the spec tagged @integration. It carries a Mount Map
# (## Mount Map section / Composition table) naming every feature and where it
# mounts (route / region / nav entry). It is itself exempt from this check
# (it is the host, not a mountee).
#
# Contract vs reality: this hook enforces the SPEC-LEVEL contract (feature is
# in the Mount Map or visibly imported). Runtime reachability — that the
# assembled app actually reaches the feature from its real entry point — is
# verified by the qa-engineer Step 4.1 e2e and the release-coordinator orphan
# check. Hook enforces the contract; agents verify the running app.
#
# Escape hatch:
#   @mount-skip(reason)        — this feature legitimately isn't mounted in a
#                                shell (e.g. it is a sub-component another
#                                feature mounts, or a background-only surface).
#   @integration-skip(reason)  — this epic legitimately has no single assembly
#                                owner (rare for >=2 UI specs; document why).
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

# Is this a user-facing feature spec?
if ! echo "$spec_content" | grep -qE "@layer\((ui|full-stack)\)"; then
    echo '{}'
    exit 0
fi

# The integration spec is itself the host — exempt it.
if echo "$spec_content" | grep -qE "@integration\b"; then
    echo '{}'
    exit 0
fi

# Escape hatches
if echo "$spec_content" | grep -qE "@mount-skip\([^)]+\)"; then
    echo '{}'
    exit 0
fi
if echo "$spec_content" | grep -qE "@integration-skip\([^)]+\)"; then
    echo '{}'
    exit 0
fi

slug="${basename_file%.md}"
spec_dir="$(dirname "$file_path")"
project_root="$(dirname "$spec_dir")"

# ---------- Scope gate: only multi-feature user-facing epics ----------
# Count user-facing specs in specs/ (excluding system.md / arch.md). If fewer
# than 2, this is a single-UI-feature epic (or non-UI) — exempt.
ui_spec_count=0
for s in "$spec_dir"/*.md; do
    [ -f "$s" ] || continue
    b="$(basename "$s")"
    [[ "$b" == "system.md" || "$b" == "arch.md" ]] && continue
    if grep -qE "@layer\((ui|full-stack)\)" "$s" 2>/dev/null; then
        ui_spec_count=$((ui_spec_count + 1))
    fi
done

if [ "$ui_spec_count" -lt 2 ]; then
    echo '{}'
    exit 0
fi

# ---------- Find the integration spec(s) ----------
# An integration spec is any spec (other than this one) tagged @integration.
integration_specs=()
for s in "$spec_dir"/*.md; do
    [ -f "$s" ] || continue
    [ "$s" = "$file_path" ] && continue
    if grep -qE "@integration\b" "$s" 2>/dev/null; then
        integration_specs+=("$s")
    fi
done

if [ ${#integration_specs[@]} -eq 0 ]; then
    cat >&2 <<EOF
BLOCKED: specs/${slug}.md (@layer ui/full-stack) is being marked @status(verified), but this epic has ${ui_spec_count} user-facing specs and NO integration spec.

A multi-feature user-facing product needs exactly one spec that OWNS assembly —
the app shell / entry point that mounts every feature into one reachable
product. Without it, features ship as a launchpad of disconnected demo cards
(this is the SquashBuckler dogfood failure this gate prevents).

Fix:
  1. Create/designate the integration spec. Tag it @integration and @layer(ui).
     It @depends-on every UI feature and carries a "## Mount Map" section:
       | Feature spec | Mounts as | Where (route / region / nav) |
  2. Add this feature to that Mount Map, and tag this spec:
       @mounts-in(<integration-spec-slug>)

This should have been planned at /design Step 2.5 (decomposition). See
application-architect's assembly step and build/SKILL.md Step 4.1.

To override (rare — document why this epic has no single assembly owner):
  @integration-skip(<reason>)
To override for just this feature (it is mounted by another feature, not the shell):
  @mount-skip(<reason>)
EOF
    exit 2
fi

# ---------- Check 1: listed in an integration spec's Mount Map ----------
# Satisfied if any integration spec references this slug anywhere in its body
# (the Mount Map / Composition table names the feature by slug).
in_mount_map="no"
for isp in "${integration_specs[@]}"; do
    if grep -q "$slug" "$isp" 2>/dev/null; then
        in_mount_map="yes"
        break
    fi
done

if [ "$in_mount_map" = "yes" ]; then
    echo '{}'
    exit 0
fi

# ---------- Check 2 (rescue): imported by application source ----------
# Best-effort, additive-only: this can only let the edit through, never block
# on its own. A feature wired into the app but not yet added to the Mount Map
# should not be blocked. Searches for the slug and its PascalCase form inside
# import-ish lines, excluding the feature's own files, specs, tests, vendor.
pascal="$(echo "$slug" | awk -F- '{out=""; for(i=1;i<=NF;i++){out=out toupper(substr($i,1,1)) substr($i,2)} print out}')"

imported="no"
if command -v grep >/dev/null 2>&1; then
    # Search common source roots under the project root, not the specs dir.
    if grep -rIlE "(import|from|require|use |mod )" "$project_root" \
            --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
            --include='*.mjs' --include='*.cjs' --include='*.vue' --include='*.svelte' \
            --include='*.rs' --include='*.go' --include='*.py' --include='*.swift' \
            --include='*.kt' --include='*.java' \
            --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=target \
            --exclude-dir=dist --exclude-dir=build --exclude-dir=specs \
            --exclude-dir=tests --exclude-dir=e2e --exclude-dir=__tests__ \
            2>/dev/null \
        | xargs grep -lE "(\\b${pascal}\\b|${slug})" 2>/dev/null \
        | grep -q .; then
        imported="yes"
    fi
fi

if [ "$imported" = "yes" ]; then
    # Mounted in code but missing from the Mount Map — allow, but nudge to
    # keep the contract in sync via additionalContext (non-blocking).
    json_encode_context "
[MOUNT MAP] specs/${slug}.md appears imported in application source but is NOT listed in the integration spec's Mount Map ($(basename "${integration_specs[0]}")). Add a row for it so the assembly contract stays authoritative:
  | ${slug} | <component> | <route/region/nav> |
and tag this spec @mounts-in($(basename "${integration_specs[0]}" .md))."
    exit 0
fi

# ---------- Neither: this is an orphan feature ----------
cat >&2 <<EOF
BLOCKED: specs/${slug}.md (@layer ui/full-stack) is being marked @status(verified), but the feature is not assembled into the product.

  - Not listed in any integration spec's Mount Map ($(printf '%s ' "${integration_specs[@]#$project_root/specs/}"))
  - Not visibly imported by the application source

"Verified" must mean the feature is reachable in the running product, not just
that its own unit tests pass. An unmounted feature is a disconnected demo card
(the SquashBuckler dogfood failure this gate prevents).

Fix one of:
  1. Mount it: import/route the feature from the app entry point so it is
     reachable, then add it to the integration spec's Mount Map and tag this
     spec @mounts-in(<integration-spec-slug>).
  2. If this feature is mounted by ANOTHER feature (not the shell), say so:
       @mount-skip(mounted by <other-feature>: <reason>)

Reference: build/SKILL.md Step 4.1 (assembled-app e2e) and the integration
spec's Mount Map. Runtime reachability is independently verified by qa-engineer
Step 4.1 and the release-coordinator orphan check before epic close.
EOF
exit 2
