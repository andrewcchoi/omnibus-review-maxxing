#!/bin/bash

# Omnibus Review Loop Stop Hook
# Prevents session exit when an omnibus review loop is active
# Continues the review cycle until all CRITICAL/HIGH issues are resolved

set -euo pipefail

# Read hook input from stdin (advanced stop hook API)
HOOK_INPUT=$(cat)

# Check if omnibus review loop is active
REVIEW_STATE_FILE=".claude/omnibus-review-loop.local.md"

if [[ ! -f "$REVIEW_STATE_FILE" ]]; then
  # No active loop - allow exit
  exit 0
fi

# Parse markdown frontmatter (YAML between ---) and extract values
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$REVIEW_STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
# Extract completion_promise and strip surrounding quotes if present
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')

# Session isolation: verify this hook should run in this session
STATE_SESSION=$(echo "$FRONTMATTER" | grep '^session_id:' | sed 's/session_id: *//' || true)
HOOK_SESSION=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""')
if [[ -n "$STATE_SESSION" ]] && [[ "$STATE_SESSION" != "$HOOK_SESSION" ]]; then
  # Different session - allow exit
  exit 0
fi

# Validate numeric fields before arithmetic operations
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]]; then
  echo "Omnibus Review Loop: State file corrupted (invalid iteration: '$ITERATION')" >&2
  echo "Stopping loop. Run setup-review-loop.sh again to start fresh." >&2
  rm "$REVIEW_STATE_FILE"
  exit 0
fi

if [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "Omnibus Review Loop: State file corrupted (invalid max_iterations: '$MAX_ITERATIONS')" >&2
  echo "Stopping loop. Run setup-review-loop.sh again to start fresh." >&2
  rm "$REVIEW_STATE_FILE"
  exit 0
fi

# Check if max iterations reached
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "Omnibus Review Loop: Max iterations ($MAX_ITERATIONS) reached." >&2
  echo "Stopping loop." >&2
  rm "$REVIEW_STATE_FILE"
  exit 0
fi

# Get transcript path from hook input
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "Omnibus Review Loop: Transcript file not found at $TRANSCRIPT_PATH" >&2
  echo "This may indicate a Claude Code internal issue." >&2
  echo "Stopping loop." >&2
  rm "$REVIEW_STATE_FILE"
  exit 0
fi

# Read last assistant message from transcript (JSONL format)
if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  echo "Omnibus Review Loop: No assistant messages found in transcript" >&2
  echo "Stopping loop." >&2
  rm "$REVIEW_STATE_FILE"
  exit 0
fi

# Extract the most recent assistant text block
# Take last 100 assistant lines to keep bounded for long sessions
LAST_LINES=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -n 100)
if [[ -z "$LAST_LINES" ]]; then
  echo "Omnibus Review Loop: Failed to extract assistant messages" >&2
  echo "Stopping loop." >&2
  rm "$REVIEW_STATE_FILE"
  exit 0
fi

# Parse the recent lines and pull out the final text block
set +e
LAST_OUTPUT=$(echo "$LAST_LINES" | jq -rs '
  map(.message.content[]? | select(.type == "text") | .text) | last // ""
' 2>&1)
JQ_EXIT=$?
set -e

# Check if jq succeeded
if [[ $JQ_EXIT -ne 0 ]]; then
  echo "Omnibus Review Loop: Failed to parse assistant message JSON" >&2
  echo "Error: $LAST_OUTPUT" >&2
  echo "Stopping loop." >&2
  rm "$REVIEW_STATE_FILE"
  exit 0
fi

# Check for completion promise
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  # Extract text from <promise> tags using Perl for multiline support
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")

  # Use = for literal string comparison (not pattern matching)
  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    echo "Omnibus Review Loop: Detected completion promise <promise>$COMPLETION_PROMISE</promise>" >&2
    echo "All CRITICAL and HIGH issues resolved!" >&2
    rm "$REVIEW_STATE_FILE"
    exit 0
  fi
fi

# Not complete - continue loop with SAME PROMPT
NEXT_ITERATION=$((ITERATION + 1))

# Extract prompt (everything after the closing ---)
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$REVIEW_STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "Omnibus Review Loop: State file corrupted or incomplete (no prompt text)" >&2
  echo "Stopping loop. Run setup-review-loop.sh again to start fresh." >&2
  rm "$REVIEW_STATE_FILE"
  exit 0
fi

# Update iteration in frontmatter
TEMP_FILE="${REVIEW_STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$REVIEW_STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$REVIEW_STATE_FILE"

# Build system message with iteration count
SYSTEM_MSG="Omnibus Review iteration $NEXT_ITERATION"
if [[ $MAX_ITERATIONS -gt 0 ]]; then
  SYSTEM_MSG="$SYSTEM_MSG/$MAX_ITERATIONS"
fi
SYSTEM_MSG="$SYSTEM_MSG | Fix CRITICAL/HIGH issues, then re-run review"

# Output JSON to block the stop and feed prompt back
jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

# Exit 0 for successful hook execution
exit 0
