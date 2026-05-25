---
description: "Cancel active omnibus review loop"
argument-hint: ""
allowed-tools: ["Bash"]
---

# Cancel Omnibus Review Loop

This command cancels an active omnibus review Ralph Loop if one is running.

## Implementation

Check for the state file and remove it if it exists:

<function_calls>
<invoke name="Bash">
<parameter name="command">STATE_FILE=".claude/omnibus-review-loop.local.md"
HANDOFF_FILE=".claude/omnibus-review-handoff.local.html"

if [ -f "$STATE_FILE" ]; then
  iteration=$(grep '^iteration:' "$STATE_FILE" | awk '{print $2}')
  rm -f "$STATE_FILE" "$HANDOFF_FILE"
  echo "Cancelled omnibus review loop (was at iteration $iteration)"
  if [ -f "$HANDOFF_FILE" ]; then
    echo "Note: Handoff file was also removed"
  fi
else
  echo "No active omnibus review loop to cancel"
fi