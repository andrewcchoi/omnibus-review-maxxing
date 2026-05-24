---
description: "Comprehensive code review with iterative fixing"
argument-hint: "[--fix] [--max-iterations N] [--opus] [files...]"
allowed-tools: ["Bash", "Read", "Write", "Edit", "Grep", "Glob", "Agent"]
---

# Omnibus Review Command

Run a comprehensive multi-agent code review with optional iterative fixing.

## Phase 1: Determine Scope and Parse Arguments

First, parse the arguments and determine what to review:

```bash
cd /mnt/d/_wip/resumate-platform

# Parse arguments from $ARGUMENTS
# Note: $ARGUMENTS is injected by Claude Code's command system
# It contains the raw argument string passed to this command
FIX_MODE=false
MAX_ITERATIONS=4
USE_OPUS=false
FILES=()

for arg in $ARGUMENTS; do
  case "$arg" in
    --fix)
      FIX_MODE=true
      ;;
    --max-iterations)
      # Next arg will be the number
      NEXT_IS_MAX_ITER=true
      ;;
    --opus)
      USE_OPUS=true
      ;;
    *)
      if [ "$NEXT_IS_MAX_ITER" = true ]; then
        MAX_ITERATIONS="$arg"
        NEXT_IS_MAX_ITER=false
      else
        FILES+=("$arg")
      fi
      ;;
  esac
done

# Determine file scope
if [ ${#FILES[@]} -eq 0 ]; then
  # No files specified - use git diff
  mapfile -t FILES < <(git diff --name-only --diff-filter=ACMR)
  
  if [ ${#FILES[@]} -eq 0 ]; then
    echo "ERROR: No files to review. Either specify files explicitly or ensure you have uncommitted changes."
    exit 1
  fi
  
  echo "Reviewing ${#FILES[@]} files from git diff"
else
  echo "Reviewing ${#FILES[@]} specified files"
fi

# Normalize to absolute paths from repository root
NORMALIZED_FILES=()
for file in "${FILES[@]}"; do
  # Convert relative paths to absolute paths
  if [[ "$file" != /* ]]; then
    file="/mnt/d/_wip/resumate-platform/$file"
  fi
  NORMALIZED_FILES+=("$file")
done
FILES=("${NORMALIZED_FILES[@]}")

# Output file list for agents
echo "Files to review:"
printf '%s\n' "${FILES[@]}"
```

Next, gather the project context from CLAUDE.md and related documentation:

Use Read to load `/mnt/d/_wip/resumate-platform/CLAUDE.md` - this contains essential architecture patterns, tech stack, and coding standards.

Store the key sections that are relevant for code review:
- Project Overview and Tech Stack
- Architecture Patterns
- Common Pitfalls (DO/DO NOT lists)
- Testing Strategy
- Directory Structure

## Phase 2: Dispatch 6 Parallel Review Agents

Launch all 6 specialized review agents in parallel. Each agent receives:
- The list of files to review
- Relevant CLAUDE.md content
- Clear instructions to return JSON output in the specified format

All agents use Opus model with ultrathink enabled.

**Important**: The Agent tool invocation syntax shown below is conceptual/instructional. 
In practice, you'll use Claude Code's Agent tool with these parameters. The exact 
syntax depends on the tool's implementation, but the key is to pass:
- The agent identifier (e.g., "correctness-auditor")
- Model configuration (Opus with ultrathink)
- The full context string containing file list and instructions

### Agent 1: Correctness Auditor

Use Agent tool with:
- `agent: "correctness-auditor"`
- `model: "opus"`
- `options: { "ultrathink": true }`

Provide context:
```
Review these files for correctness issues:
${FILE_LIST}

Project context from CLAUDE.md:
${CLAUDE_MD_RELEVANT_SECTIONS}

Return findings as JSON array with this structure:
{
  "findings": [
    {
      "file": "path/to/file.py",
      "line_start": 42,
      "line_end": 45,
      "severity": "high",
      "confidence": 95,
      "category": "logic-error",
      "title": "Brief issue title",
      "description": "Detailed explanation",
      "suggestion": "How to fix it"
    }
  ]
}

Focus on logic errors, race conditions, incorrect async usage, and architectural violations.
Only include findings with confidence >= 80.
```

### Agent 2: Security Sentinel

Use Agent tool with:
- `agent: "security-sentinel"`
- `model: "opus"`
- `options: { "ultrathink": true }`

Provide context:
```
Review these files for security vulnerabilities:
${FILE_LIST}

Project context from CLAUDE.md:
${CLAUDE_MD_RELEVANT_SECTIONS}

Return findings as JSON array with the same structure as above.

Focus on SQL injection, authentication issues, authorization bypasses, secret exposure, and data validation.
Only include findings with confidence >= 80.
```

### Agent 3: Claude MD Compliance

Use Agent tool with:
- `agent: "claude-md-compliance"`
- `model: "opus"`
- `options: { "ultrathink": true }`

Provide context:
```
Review these files for CLAUDE.md compliance:
${FILE_LIST}

Full CLAUDE.md content:
${FULL_CLAUDE_MD}

Return findings as JSON array with the same structure as above.

Check for violations of architecture patterns, coding standards, and DO NOT rules.
Only include findings with confidence >= 80.
```

### Agent 4: Test Coverage Analyzer

Use Agent tool with:
- `agent: "test-coverage-analyzer"`
- `model: "opus"`
- `options: { "ultrathink": true }`

Provide context:
```
Analyze test coverage for these files:
${FILE_LIST}

Project context from CLAUDE.md:
${CLAUDE_MD_RELEVANT_SECTIONS}

Return findings as JSON array with the same structure as above.

Identify untested functions, missing edge cases, and inadequate test isolation.
Only include findings with confidence >= 80.
```

### Agent 5: Silent Failure Hunter

Use Agent tool with:
- `agent: "silent-failure-hunter"`
- `model: "opus"`
- `options: { "ultrathink": true }`

Provide context:
```
Hunt for silent failures in these files:
${FILE_LIST}

Project context from CLAUDE.md:
${CLAUDE_MD_RELEVANT_SECTIONS}

Return findings as JSON array with the same structure as above.

Look for swallowed exceptions, missing error handling, unchecked return values, and ignored validation errors.
Only include findings with confidence >= 80.
```

### Agent 6: Code Quality Reviewer

Use Agent tool with:
- `agent: "code-quality-reviewer"`
- `model: "opus"`
- `options: { "ultrathink": true }`

Provide context:
```
Review code quality in these files:
${FILE_LIST}

Project context from CLAUDE.md:
${CLAUDE_MD_RELEVANT_SECTIONS}

Return findings as JSON array with the same structure as above.

Focus on maintainability issues, unclear naming, excessive complexity, and poor documentation.
Only include findings with confidence >= 80.
```

## Phase 3: Aggregate and Deduplicate Findings

After all agents complete, collect their JSON outputs:

1. **Parse JSON from each agent response**: 
   - First attempt: Look for JSON within ```json fenced code blocks
   - Second attempt: If no fenced blocks found, scan for raw JSON patterns (starts with `{` or `[`, ends with `}` or `]`)
   - Extract the "findings" array from each agent's response

2. **Merge all findings arrays**: Combine findings from all 6 agents into one array

3. **Filter by confidence**: Remove any findings with confidence < 80
   - Note: This is defensive programming. Agents are instructed to only return findings >= 80 confidence, 
     but this filter ensures quality in case an agent doesn't follow instructions precisely

4. **Deduplicate by location**: 
   - Two findings are duplicates if they have:
     - Same file path
     - Overlapping line ranges (line_start to line_end)
   - When duplicates found, keep the one with highest confidence
   - If confidence is equal, keep the one with higher severity (critical > high > medium > low)

5. **Sort by severity**: Order final list as critical, high, medium, low

Store the final aggregated findings in a structured format for Phase 4.

## Phase 4: Report or Fix

### Report Mode (default)

If `FIX_MODE=false`, output a human-readable summary:

```
=== Omnibus Review Results ===

Reviewed ${FILE_COUNT} files
Found ${TOTAL_FINDINGS} issues after deduplication

Breakdown by severity:
- Critical: ${CRITICAL_COUNT}
- High: ${HIGH_COUNT}
- Medium: ${MEDIUM_COUNT}
- Low: ${LOW_COUNT}

=== Critical Issues ===
[List each critical finding with file, lines, title, description]

=== High Priority Issues ===
[List each high finding with file, lines, title, description]

=== Medium Priority Issues ===
[List each medium finding with file, lines, title, description]

=== Low Priority Issues ===
[List each low finding with file, lines, title, description]

---
Review complete. Run with --fix to automatically address these issues.
```

End with the exit phrase:
```
<promise>QUANTUM_EIGENSTATE_CRYSTALLIZED_OMEGA</promise>
```

### Fix Mode

If `FIX_MODE=true`, initialize Ralph Loop for iterative fixing:

1. **Save findings to temp file**: Write aggregated findings JSON to `$TMPDIR/omnibus-findings.json`

2. **Initialize Ralph Loop**: Execute the Ralph Loop setup script:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-review-loop.sh" \
  --findings "$TMPDIR/omnibus-findings.json" \
  --max-iterations "$MAX_ITERATIONS" \
  --model "$([ "$USE_OPUS" = true ] && echo 'opus' || echo 'sonnet')"
```

3. **Report initialization**:
```
=== Omnibus Review with Iterative Fixing ===

Initial findings: ${TOTAL_FINDINGS} issues
Max iterations: ${MAX_ITERATIONS}
Model: ${MODEL_NAME}

Ralph Loop initialized. Starting iterative fixing...

[The script will handle the loop execution and re-review cycles]
```

4. **Exit phrase**: After Ralph Loop completes (or in any error case), output:
```
<promise>QUANTUM_EIGENSTATE_CRYSTALLIZED_OMEGA</promise>
```

## Error Handling

The following error scenarios require specific handling:

1. **Agent fails to return valid JSON**:
   - Retry the agent call once with clarified instructions
   - If second attempt fails, skip that agent and note "Agent error: [agent-name]" in final summary
   - Continue with remaining agents

2. **Agent timeout** (no response after reasonable wait):
   - Skip the agent after timeout
   - Note "Agent timeout: [agent-name]" in final summary
   - Continue with remaining agents

3. **Ralph Loop script missing** (in --fix mode):
   - Check if `${CLAUDE_PLUGIN_ROOT}/scripts/setup-review-loop.sh` exists
   - If missing, warn: "Ralph Loop script not found - continuing in report-only mode"
   - Fall back to report mode behavior

4. **Git diff fails** (empty working directory or git not available):
   - Require explicit file list: "ERROR: No files to review. Either specify files explicitly or ensure you have uncommitted changes."
   - Exit with code 1

5. **JSON parsing issues**:
   - Try ```json fenced blocks first
   - Fall back to raw JSON detection (look for object/array boundaries)
   - If both fail, treat as "Agent fails to return valid JSON" (retry once)

## Implementation Notes

- All file paths should be absolute paths from the repository root
- Relative paths are normalized to absolute in Phase 1 (prepend repository root)
- Agent tool calls use bare agent names (e.g., "correctness-auditor") - they're local to this plugin
- JSON parsing should be robust - handle both fenced code blocks and raw JSON
- Deduplication algorithm: use a map keyed by file path, then check line overlaps within same file
- The Ralph Loop script (Task 4) handles the iterative fix-review cycle
- Always output the exit phrase at the end, regardless of success or failure
