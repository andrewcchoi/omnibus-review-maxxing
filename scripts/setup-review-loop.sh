#!/bin/bash

# Omnibus Review Loop Setup Script
# Creates state file for in-session omnibus review loop

set -euo pipefail

# Parse arguments
MAX_ITERATIONS=0
COMPLETION_PROMISE="QUANTUM_EIGENSTATE_CRYSTALLIZED_OMEGA"

# Parse options
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Omnibus Review Loop - Iterative review and fix cycle

USAGE:
  ./setup-review-loop.sh [OPTIONS]

OPTIONS:
  --max-iterations <n>           Maximum iterations before auto-stop (default: unlimited)
  --completion-promise '<text>'  Promise phrase (default: QUANTUM_EIGENSTATE_CRYSTALLIZED_OMEGA)
  -h, --help                     Show this help message

DESCRIPTION:
  Starts an Omnibus Review Loop in your CURRENT session. The stop hook prevents
  exit and continues the review cycle until all CRITICAL and HIGH issues are resolved.

  To signal completion, output: <promise>QUANTUM_EIGENSTATE_CRYSTALLIZED_OMEGA</promise>

  The loop will:
  1. Run omnibus review
  2. Fix CRITICAL and HIGH issues
  3. Re-run review
  4. Repeat until completion or max iterations

EXAMPLES:
  ./setup-review-loop.sh --max-iterations 4
  ./setup-review-loop.sh --max-iterations 10 --completion-promise 'ALL_ISSUES_RESOLVED'

STOPPING:
  Only by reaching --max-iterations or detecting --completion-promise
  No manual stop - loop runs infinitely by default!

MONITORING:
  # View current iteration:
  grep '^iteration:' .claude/omnibus-review-loop.local.md

  # View full state:
  head -10 .claude/omnibus-review-loop.local.md
HELP_EOF
      exit 0
      ;;
    --max-iterations)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --max-iterations requires a number argument" >&2
        echo "" >&2
        echo "   Valid examples:" >&2
        echo "     --max-iterations 4" >&2
        echo "     --max-iterations 10" >&2
        echo "     --max-iterations 0  (unlimited)" >&2
        exit 1
      fi
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-iterations must be a positive integer or 0, got: $2" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --completion-promise)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --completion-promise requires a text argument" >&2
        echo "" >&2
        echo "   Example: --completion-promise 'QUANTUM_EIGENSTATE_CRYSTALLIZED_OMEGA'" >&2
        exit 1
      fi
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Use --help for usage information" >&2
      exit 1
      ;;
  esac
done

# Create state file for stop hook (markdown with YAML frontmatter)
mkdir -p .claude

# Quote completion promise for YAML
COMPLETION_PROMISE_YAML="\"$COMPLETION_PROMISE\""
STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-unknown}"

cat > .claude/omnibus-review-loop.local.md <<EOF
---
active: true
iteration: 1
session_id: $SESSION_ID
max_iterations: $MAX_ITERATIONS
completion_promise: $COMPLETION_PROMISE_YAML
started_at: "$STARTED_AT"
---

Continue omnibus review and fix cycle.
Fix remaining CRITICAL and HIGH issues.
Re-run review after each fix cycle.
Output <promise>$COMPLETION_PROMISE</promise> when no CRITICAL or HIGH issues remain.
EOF

# Create handoff HTML file with initial state (direct write for reliability)
cat > .claude/omnibus-review-handoff.local.html <<'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Omnibus Review Progress</title>
  <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
  <style>
    :root {
      --safe: #10b981; --safe-bg: #d1fae5; --safe-text: #065f46;
      --medium: #f59e0b; --medium-bg: #fef3c7; --medium-text: #92400e;
      --attention: #ef4444; --attention-bg: #fee2e2; --attention-text: #991b1b;
    }
    body { font-family: system-ui, -apple-system, sans-serif; max-width: 900px; margin: 0 auto; padding: 2rem; background: #f9fafb; color: #111827; }
    h1 { margin-bottom: 0.5rem; }
    .chip { display: inline-block; padding: 0.25rem 0.75rem; border-radius: 9999px; font-size: 0.875rem; font-weight: 500; margin-right: 0.5rem; }
    .chip.safe { background: var(--safe-bg); color: var(--safe-text); }
    .chip.medium { background: var(--medium-bg); color: var(--medium-text); }
    .chip.attention { background: var(--attention-bg); color: var(--attention-text); }
    .iteration { background: white; border-radius: 0.5rem; padding: 1.5rem; margin: 1rem 0; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
    .iteration.current { border-left: 4px solid var(--medium); }
    .iteration.complete { border-left: 4px solid var(--safe); }
    .iteration h2 { margin-top: 0; }
    .stats { margin-bottom: 1rem; }
    details { margin: 0.5rem 0; }
    summary { cursor: pointer; font-weight: 500; }
    ul { margin: 0.5rem 0; padding-left: 1.5rem; }
    li { margin: 0.25rem 0; }
    code { background: #e5e7eb; padding: 0.125rem 0.375rem; border-radius: 0.25rem; font-size: 0.875rem; }
    .mermaid { background: white; padding: 1rem; border-radius: 0.5rem; margin: 1rem 0; }
    .iteration-history { margin-top: 2rem; }
    .meta { color: #6b7280; font-size: 0.875rem; margin-bottom: 1rem; }
  </style>
</head>
<body>
  <!-- MACHINE-READABLE YAML (Claude parses this block for iteration state) -->
  <script id="handoff-data" type="application/yaml">
HTMLEOF

# Append YAML content with variable substitution
cat >> .claude/omnibus-review-handoff.local.html <<EOF
iteration: 1
max_iterations: $MAX_ITERATIONS
session_id: "$SESSION_ID"
status: "STARTING"
completion_promise: $COMPLETION_PROMISE_YAML
started_at: "$STARTED_AT"
last_review_summary:
  critical_count: 0
  high_count: 0
  medium_count: 0
  low_count: 0
  files_fixed: []
  still_needs_work: []
review_scope:
  files: []
  mode: "fix"
context: "Starting omnibus review loop. No prior iterations."
EOF

# Append rest of HTML
cat >> .claude/omnibus-review-handoff.local.html <<HTMLEOF
  </script>

  <!-- HUMAN-READABLE PROGRESS -->
  <h1>Omnibus Review Progress</h1>
  <p class="meta">Session: $SESSION_ID | Started: $STARTED_AT</p>

  <div class="mermaid">
flowchart LR
    I1[Iteration 1<br/>Starting...]
    style I1 fill:#fef3c7
  </div>

  <section class="iteration current" id="iter-1">
    <h2>Iteration 1 <span class="chip medium">STARTING</span></h2>
    <div class="stats">
      <span class="chip safe">0 Critical</span>
      <span class="chip safe">0 High</span>
    </div>
    <p>Initializing review cycle...</p>
  </section>

  <script>mermaid.initialize({startOnLoad: true});</script>
</body>
</html>
HTMLEOF

# Output setup message
cat <<EOF
Omnibus Review Loop activated in this session!

Iteration: 1
Max iterations: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)
Completion promise: $COMPLETION_PROMISE

The stop hook is now active. When you try to exit, the review cycle will
continue automatically. You'll iteratively fix CRITICAL and HIGH issues
and re-run the review until completion.

To monitor: head -10 .claude/omnibus-review-loop.local.md

WARNING: This loop cannot be stopped manually! It will run infinitely
    unless you set --max-iterations or it detects the completion promise.

CRITICAL - Omnibus Review Loop Completion
═══════════════════════════════════════════════════════════
To complete this loop, output this EXACT text:
  <promise>$COMPLETION_PROMISE</promise>

STRICT REQUIREMENTS:
  ✓ Use <promise> XML tags EXACTLY as shown above
  ✓ The statement MUST be completely TRUE
  ✓ Do NOT output false statements to exit the loop
  ✓ Only output when NO CRITICAL or HIGH issues remain

IMPORTANT:
  Even if you believe you're stuck or the task is impossible,
  you MUST NOT output a false promise statement. The loop is
  designed to continue until all CRITICAL and HIGH issues are
  genuinely resolved. Trust the process.
═══════════════════════════════════════════════════════════

Continue omnibus review and fix cycle.
Fix remaining CRITICAL and HIGH issues.
Re-run review after each fix cycle.
Output <promise>$COMPLETION_PROMISE</promise> when no CRITICAL or HIGH issues remain.
EOF
