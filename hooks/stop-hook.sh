#!/bin/bash

# Omnibus Review Loop Stop Hook
# Prevents session exit when an omnibus-review loop is active
# Feeds the review prompt back as input to continue the fix cycle

set -euo pipefail

# Read hook input from stdin (advanced stop hook API)
HOOK_INPUT=$(cat)

# Check if omnibus-review loop is active
STATE_FILE=".claude/omnibus-review-loop.local.md"
HANDOFF_FILE=".claude/omnibus-review-handoff.local.html"

if [[ ! -f "$STATE_FILE" ]]; then
  # No active loop - allow exit
  exit 0
fi

# Parse markdown frontmatter (YAML between ---) and extract values
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
# Extract completion_promise and strip surrounding quotes if present
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')

# Session isolation: the state file is project-scoped, but the Stop hook
# fires in every Claude Code session in that project. If another session
# started the loop, this session must not block (or touch the state file).
STATE_SESSION=$(echo "$FRONTMATTER" | grep '^session_id:' | sed 's/session_id: *//' || true)
HOOK_SESSION=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""')
if [[ -n "$STATE_SESSION" ]] && [[ "$STATE_SESSION" != "$HOOK_SESSION" ]]; then
  exit 0
fi

# Validate numeric fields before arithmetic operations
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]]; then
  echo "Warning: Omnibus review loop state file corrupted (invalid iteration)" >&2
  echo "   Problem: 'iteration' field is not a valid number (got: '$ITERATION')" >&2
  echo "   Stopping loop. Run /omnibus-review-loop again to start fresh." >&2
  rm "$STATE_FILE"
  exit 0
fi

if [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "Warning: Omnibus review loop state file corrupted (invalid max_iterations)" >&2
  echo "   Problem: 'max_iterations' field is not a valid number (got: '$MAX_ITERATIONS')" >&2
  echo "   Stopping loop. Run /omnibus-review-loop again to start fresh." >&2
  rm "$STATE_FILE"
  exit 0
fi

# Check if max iterations reached
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "Omnibus review loop: Max iterations ($MAX_ITERATIONS) reached."
  rm "$STATE_FILE"
  exit 0
fi

# Get transcript path from hook input
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "Warning: Omnibus review loop transcript not found" >&2
  echo "   Expected: $TRANSCRIPT_PATH" >&2
  echo "   Stopping loop." >&2
  rm "$STATE_FILE"
  exit 0
fi

# Read last assistant message from transcript (JSONL format - one JSON per line)
# First check if there are any assistant messages
if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  echo "Warning: No assistant messages found in transcript" >&2
  echo "   Stopping loop." >&2
  rm "$STATE_FILE"
  exit 0
fi

# Extract the most recent assistant text block.
# Claude Code writes each content block as its own JSONL line with role=assistant.
# Slurp the last 100 assistant lines to keep jq bounded for long sessions.
LAST_LINES=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -n 100)
if [[ -z "$LAST_LINES" ]]; then
  echo "Warning: Failed to extract assistant messages" >&2
  echo "   Stopping loop." >&2
  rm "$STATE_FILE"
  exit 0
fi

# Parse the recent lines and pull out the final text block.
set +e
LAST_OUTPUT=$(echo "$LAST_LINES" | jq -rs '
  map(.message.content[]? | select(.type == "text") | .text) | last // ""
' 2>&1)
JQ_EXIT=$?
set -e

# Check if jq succeeded
if [[ $JQ_EXIT -ne 0 ]]; then
  echo "Warning: Failed to parse assistant message JSON" >&2
  echo "   Error: $LAST_OUTPUT" >&2
  echo "   Stopping loop." >&2
  rm "$STATE_FILE"
  exit 0
fi

# Check for completion promise in transcript
if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  # Extract text from <promise> tags using Perl for multiline support
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")

  # Use = for literal string comparison (not pattern matching)
  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    echo "Omnibus review loop complete: Detected <promise>$COMPLETION_PROMISE</promise>"
    rm -f "$STATE_FILE" "$HANDOFF_FILE"
    exit 0
  fi
fi

# Also check handoff file for COMPLETE status (set by omnibus-review command)
if [[ -f "$HANDOFF_FILE" ]]; then
  HANDOFF_YAML=$(sed -n '/<script id="handoff-data" type="application\/yaml">/,/<\/script>/p' "$HANDOFF_FILE" 2>/dev/null | sed '1d;$d')
  HANDOFF_STATUS=$(echo "$HANDOFF_YAML" | grep '^status:' | sed 's/status: *//' | tr -d '"' || echo "")

  if [[ "$HANDOFF_STATUS" == "COMPLETE" ]]; then
    echo "Omnibus review loop complete: status=COMPLETE in handoff file"
    rm -f "$STATE_FILE" "$HANDOFF_FILE"
    exit 0
  fi
fi

# Not complete - continue loop with MINIMAL PROMPT (context isolation)
NEXT_ITERATION=$((ITERATION + 1))

# Update iteration in state file frontmatter (portable across macOS and Linux)
TEMP_FILE="${STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

# Also update iteration in handoff file YAML if it exists
if [[ -f "$HANDOFF_FILE" ]]; then
  TEMP_HANDOFF="${HANDOFF_FILE}.tmp.$$"
  sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$HANDOFF_FILE" > "$TEMP_HANDOFF"
  mv "$TEMP_HANDOFF" "$HANDOFF_FILE"
fi

# Build MINIMAL prompt for context isolation
# Instead of full prompt text, reference the handoff file for state
MINIMAL_PROMPT="Omnibus Review Iteration $NEXT_ITERATION.

Read .claude/omnibus-review-handoff.local.html for context from previous iteration.
Continue the review and fix cycle for files in review_scope.
When no CRITICAL or HIGH issues remain, output:
<promise>$COMPLETION_PROMISE</promise>"

# Build system message with iteration count
SYSTEM_MSG="Omnibus Review iteration $NEXT_ITERATION | Fresh context | Read handoff file first"

# Output JSON to block the stop and feed MINIMAL prompt back
jq -n \
  --arg prompt "$MINIMAL_PROMPT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

# Exit 0 for successful hook execution
exit 0
