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

cat > .claude/omnibus-review-loop.local.md <<EOF
---
active: true
iteration: 1
session_id: ${CLAUDE_CODE_SESSION_ID:-}
max_iterations: $MAX_ITERATIONS
completion_promise: $COMPLETION_PROMISE_YAML
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

Continue omnibus review and fix cycle.
Fix remaining CRITICAL and HIGH issues.
Re-run review after each fix cycle.
Output <promise>$COMPLETION_PROMISE</promise> when no CRITICAL or HIGH issues remain.
EOF

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
