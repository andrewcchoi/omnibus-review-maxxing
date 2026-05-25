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
<parameter name="command">if [ -f .claude/omnibus-review-loop.local.md ]; then
  iteration=$(grep '^iteration:' .claude/omnibus-review-loop.local.md | awk '{print $2}')
  rm .claude/omnibus-review-loop.local.md
  echo "Cancelled omnibus review loop (was at iteration $iteration)"
else
  echo "No active omnibus review loop to cancel"
fi