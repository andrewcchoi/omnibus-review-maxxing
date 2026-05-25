---
description: "Comprehensive code review with iterative fixing"
argument-hint: "[--fix] [--html] [--max-iterations N] [--opus] [files...]"
allowed-tools: ["Bash", "Read", "Write", "Edit", "Grep", "Glob", "Agent"]
---

# Omnibus Review Command

Run a comprehensive multi-agent code review with optional iterative fixing.

## Phase 1: Determine Scope and Parse Arguments

First, parse the arguments and determine what to review:

```bash
# Determine project root (git root or current directory)
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$PROJECT_ROOT"

# Validate PROJECT_ROOT
if [ ! -d "$PROJECT_ROOT" ] || [ "$PROJECT_ROOT" = "/" ]; then
  echo "ERROR: Could not determine valid project root."
  echo "Run from within a project directory or git repository."
  exit 1
fi

# Parse arguments from $ARGUMENTS
# Note: $ARGUMENTS is injected by Claude Code's command system
# It contains the raw argument string passed to this command
FIX_MODE=false
HTML_MODE=false
MAX_ITERATIONS=4
USE_OPUS=false
FILES=()

for arg in $ARGUMENTS; do
  case "$arg" in
    --fix)
      FIX_MODE=true
      ;;
    --html)
      HTML_MODE=true
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
    file="$PROJECT_ROOT/$file"
  fi
  NORMALIZED_FILES+=("$file")
done
FILES=("${NORMALIZED_FILES[@]}")

# Output file list for agents
echo "Files to review:"
printf '%s\n' "${FILES[@]}"
```

## CLAUDE.md Configuration Check

Before dispatching agents, determine CLAUDE.md configuration status.

### If CLAUDE.md Does Not Exist

Check for CLAUDE.md:
```bash
if [ ! -f "$PROJECT_ROOT/CLAUDE.md" ]; then
  echo "NO_CLAUDE_MD=true"
else
  echo "NO_CLAUDE_MD=false"
fi
```

If `NO_CLAUDE_MD=true`, use AskUserQuestion tool:
- **Question**: "No CLAUDE.md found in project root. How would you like to proceed?"
- **Options**:
  1. **"Create CLAUDE.md with /init (Recommended)"** - Invoke `/init` skill to generate project documentation, then re-run `/omnibus-review`
  2. **"Use plugin defaults"** - Use bundled `${CLAUDE_PLUGIN_ROOT}/templates/omnibus-defaults.md` for compliance checks

### If CLAUDE.md Exists But Has No Omnibus Tags

Check for omnibus-review tags:
```bash
if grep -q "omnibus-review:config\|omnibus-review:using-existing" "$PROJECT_ROOT/CLAUDE.md" 2>/dev/null; then
  echo "OMNIBUS_CONFIGURED=true"
else
  echo "OMNIBUS_CONFIGURED=false"
fi
```

If `OMNIBUS_CONFIGURED=false`, use AskUserQuestion tool:
- **Question**: "Your CLAUDE.md doesn't have omnibus-review configuration. Add defaults for better visibility and customization?"
- **Options**:
  1. **"Yes, append defaults (Recommended)"** - Use Edit tool to append `${CLAUDE_PLUGIN_ROOT}/templates/omnibus-defaults.md` content to end of CLAUDE.md
  2. **"No, use existing as-is"** - Use Edit tool to append acknowledgment tag to CLAUDE.md:
     ```
     
     <!-- omnibus-review:using-existing - Plugin uses your existing guidelines without prompting again -->
     ```
     Inform user: "Added marker tag to CLAUDE.md. Remove the `omnibus-review:using-existing` comment to reset this choice."
  3. **"No, use plugin defaults silently"** - Use bundled defaults without modifying CLAUDE.md (will prompt again next run)

### Load Effective Guidelines

After determining configuration, load the appropriate CLAUDE.md content:

```bash
# Set CLAUDE_MD_SOURCE for agent context
if [ -f "$PROJECT_ROOT/CLAUDE.md" ]; then
  CLAUDE_MD_SOURCE="$PROJECT_ROOT/CLAUDE.md"
else
  CLAUDE_MD_SOURCE="${CLAUDE_PLUGIN_ROOT}/templates/omnibus-defaults.md"
fi
```

Use Read tool to load the content from `$CLAUDE_MD_SOURCE`.

Store the key sections relevant for code review:
- Architecture Patterns
- Testing Requirements
- Security Standards
- Error Handling Standards
- Code Quality Guidelines
- DO NOT (Prohibited Patterns)

When dispatching the claude-md-compliance agent, include `CLAUDE_MD_SOURCE` in the context string so it can report accurate rule sources.

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

If `FIX_MODE=false` and `HTML_MODE=false`, output a human-readable summary:

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

### HTML Report Mode

If `HTML_MODE=true`, generate a self-contained HTML report using the HTML effectiveness patterns.

1. **Create output directory**: `mkdir -p .omnibus-review`

2. **Generate timestamp**: `TIMESTAMP=$(date +%Y%m%d_%H%M%S)`

3. **Write HTML file**: Use the Write tool to create `.omnibus-review/report_${TIMESTAMP}.html`

The HTML file must be completely self-contained (all CSS inlined, no external dependencies). Use this template structure:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Code Review Report - ${TIMESTAMP}</title>
  <style>
    /* Base styles */
    :root {
      --bg-primary: #ffffff;
      --bg-secondary: #f9fafb;
      --text-primary: #111827;
      --text-secondary: #6b7280;
      --border-color: #e5e7eb;
      --safe: #10b981;
      --safe-bg: #d1fae5;
      --safe-text: #065f46;
      --medium: #f59e0b;
      --medium-bg: #fef3c7;
      --medium-text: #92400e;
      --attention: #ef4444;
      --attention-bg: #fee2e2;
      --attention-text: #991b1b;
      --primary: #2563eb;
      --shadow: 0 1px 3px rgba(0,0,0,0.1);
    }
    * { box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      line-height: 1.6;
      color: var(--text-primary);
      background: var(--bg-secondary);
      margin: 0;
      padding: 2rem;
    }
    .container { max-width: 1000px; margin: 0 auto; background: var(--bg-primary); padding: 2rem; border-radius: 0.5rem; box-shadow: var(--shadow); }
    
    /* Header */
    .review-head { border-bottom: 3px solid var(--primary); padding-bottom: 1.5rem; margin-bottom: 2rem; }
    .review-title { font-size: 1.75rem; font-weight: 700; margin: 0 0 0.5rem; }
    .review-meta { display: flex; gap: 2rem; flex-wrap: wrap; font-size: 0.875rem; color: var(--text-secondary); }
    .stat-box { display: flex; gap: 0.5rem; align-items: center; padding: 0.5rem 1rem; background: var(--bg-secondary); border-radius: 0.5rem; }
    .stat-number { font-size: 1.5rem; font-weight: 700; }
    .stat-label { font-size: 0.75rem; text-transform: uppercase; color: var(--text-secondary); }
    
    /* Risk Map */
    .risk-map { display: flex; flex-wrap: wrap; gap: 0.5rem; padding: 1rem; background: var(--bg-secondary); border-radius: 0.5rem; margin: 1.5rem 0; }
    .risk-map-title { width: 100%; font-size: 0.75rem; font-weight: 600; text-transform: uppercase; color: var(--text-secondary); margin-bottom: 0.5rem; }
    .chip { display: inline-flex; align-items: center; gap: 0.375rem; padding: 0.375rem 0.75rem; border-radius: 9999px; font-size: 0.8125rem; font-weight: 500; text-decoration: none; transition: transform 0.15s; }
    .chip:hover { transform: translateY(-1px); }
    .chip:focus { outline: 2px solid var(--primary); outline-offset: 2px; }
    .chip.safe { background: var(--safe-bg); color: var(--safe-text); border: 1px solid var(--safe); }
    .chip.safe::before { content: '✓'; }
    .chip.medium { background: var(--medium-bg); color: var(--medium-text); border: 1px solid var(--medium); }
    .chip.medium::before { content: '◉'; }
    .chip.attention { background: var(--attention-bg); color: var(--attention-text); border: 1px solid var(--attention); }
    .chip.attention::before { content: '⚠'; }
    .risk-legend { display: flex; gap: 1rem; font-size: 0.75rem; color: var(--text-secondary); margin-top: 0.75rem; padding-top: 0.75rem; border-top: 1px solid var(--border-color); width: 100%; }
    
    /* File Cards */
    .file-card { background: var(--bg-primary); border: 1px solid var(--border-color); border-radius: 0.5rem; margin: 1.5rem 0; overflow: hidden; box-shadow: var(--shadow); }
    .file-card.highlighted { box-shadow: 0 0 0 3px var(--primary); }
    .file-head { display: flex; align-items: center; gap: 0.75rem; padding: 0.75rem 1rem; background: var(--bg-secondary); border-bottom: 1px solid var(--border-color); flex-wrap: wrap; }
    .file-path { font-family: 'Monaco', 'Menlo', monospace; font-size: 0.875rem; font-weight: 600; }
    .file-delta { font-family: monospace; font-size: 0.75rem; margin-left: auto; }
    .file-delta .added { color: var(--safe); }
    .file-delta .removed { color: var(--attention); }
    .risk-tag { display: inline-flex; align-items: center; gap: 0.25rem; padding: 0.125rem 0.5rem; border-radius: 0.25rem; font-size: 0.6875rem; font-weight: 600; text-transform: uppercase; }
    .risk-tag.safe { background: var(--safe-bg); color: var(--safe-text); }
    .risk-tag.medium { background: var(--medium-bg); color: var(--medium-text); }
    .risk-tag.attention { background: var(--attention-bg); color: var(--attention-text); }
    
    /* Comment Bubbles */
    .comments { padding: 1rem; background: var(--bg-secondary); }
    .bubble { background: var(--bg-primary); border-radius: 0.5rem; padding: 1rem; margin: 0.75rem 0; border-left: 4px solid var(--border-color); }
    .bubble:first-child { margin-top: 0; }
    .bubble .severity { display: inline-block; font-size: 0.6875rem; font-weight: 700; text-transform: uppercase; padding: 0.125rem 0.5rem; border-radius: 0.25rem; margin-bottom: 0.5rem; }
    .bubble.critical { border-left-color: var(--attention); }
    .bubble.critical .severity { background: var(--attention-bg); color: var(--attention-text); }
    .bubble.high { border-left-color: #f97316; }
    .bubble.high .severity { background: #ffedd5; color: #9a3412; }
    .bubble.medium-sev { border-left-color: var(--medium); }
    .bubble.medium-sev .severity { background: var(--medium-bg); color: var(--medium-text); }
    .bubble.low { border-left-color: var(--primary); }
    .bubble.low .severity { background: #dbeafe; color: #1e40af; }
    .bubble p { margin: 0.5rem 0 0; font-size: 0.9375rem; }
    .bubble code { background: var(--bg-secondary); padding: 0.125rem 0.375rem; border-radius: 0.25rem; font-size: 0.8125rem; }
    .bubble .location { font-family: monospace; font-size: 0.75rem; color: var(--text-secondary); margin-top: 0.5rem; }
    .bubble .agent { font-size: 0.6875rem; color: var(--text-secondary); margin-top: 0.5rem; }
    
    /* Next Steps */
    .next-steps { background: var(--bg-secondary); border: 1px solid var(--border-color); border-radius: 0.5rem; padding: 1.5rem; margin: 2rem 0; }
    .next-steps-title { font-size: 1rem; font-weight: 700; margin: 0 0 1rem; }
    .next-steps-list { list-style: none; padding: 0; margin: 0; counter-reset: step; }
    .next-steps-list li { display: flex; gap: 0.75rem; padding: 0.5rem 0; counter-increment: step; }
    .next-steps-list li::before { content: counter(step); display: flex; align-items: center; justify-content: center; width: 1.5rem; height: 1.5rem; background: var(--primary); color: white; border-radius: 50%; font-size: 0.75rem; font-weight: 600; flex-shrink: 0; }
    
    /* Accessibility */
    @media (prefers-reduced-motion: reduce) { .chip, .file-card.highlighted { transition: none; } }
    @media print { body { background: white; padding: 0; } .container { box-shadow: none; } }
  </style>
</head>
<body>
  <div class="container">
    <header class="review-head">
      <h1 class="review-title">Code Review Report</h1>
      <div class="review-meta">
        <span>Generated: ${TIMESTAMP}</span>
        <span>Files reviewed: ${FILE_COUNT}</span>
      </div>
      <div style="display: flex; gap: 1rem; margin-top: 1rem;">
        <div class="stat-box" style="border-left: 4px solid var(--attention);">
          <div><div class="stat-number">${CRITICAL_COUNT}</div><div class="stat-label">Critical</div></div>
        </div>
        <div class="stat-box" style="border-left: 4px solid #f97316;">
          <div><div class="stat-number">${HIGH_COUNT}</div><div class="stat-label">High</div></div>
        </div>
        <div class="stat-box" style="border-left: 4px solid var(--medium);">
          <div><div class="stat-number">${MEDIUM_COUNT}</div><div class="stat-label">Medium</div></div>
        </div>
        <div class="stat-box" style="border-left: 4px solid var(--primary);">
          <div><div class="stat-number">${LOW_COUNT}</div><div class="stat-label">Low</div></div>
        </div>
      </div>
    </header>

    <nav class="risk-map" role="navigation" aria-label="Files by severity">
      <div class="risk-map-title">Jump to file</div>
      <!-- For each file, generate a chip with appropriate severity class -->
      <!-- <a href="#file-hash" class="chip attention">filename.py</a> -->
      ${RISK_MAP_CHIPS}
      <div class="risk-legend">
        <span>✓ Safe</span>
        <span>◉ Needs review</span>
        <span>⚠ Attention required</span>
      </div>
    </nav>

    <main>
      <!-- For each file with findings, generate a file-card -->
      ${FILE_CARDS}
    </main>

    <section class="next-steps">
      <h2 class="next-steps-title">Suggested Next Steps</h2>
      <ol class="next-steps-list">
        <li>Address all critical issues first</li>
        <li>Review high-priority findings</li>
        <li>Run with <code>--fix</code> for automatic remediation</li>
        <li>Re-run review to verify fixes</li>
      </ol>
    </section>
  </div>
  
  <script>
    // Highlight file card on navigation
    document.querySelectorAll('.chip').forEach(chip => {
      chip.addEventListener('click', () => {
        const target = document.querySelector(chip.getAttribute('href'));
        if (target) {
          target.classList.add('highlighted');
          setTimeout(() => target.classList.remove('highlighted'), 1400);
        }
      });
    });
  </script>
</body>
</html>
```

**Generating the dynamic content**:

1. **RISK_MAP_CHIPS**: For each file with findings, generate a chip:
   - Determine the highest severity finding for that file (critical > high > medium > low)
   - Map severity to chip class: critical/high → `attention`, medium → `medium`, low → `safe`
   - Generate: `<a href="#file-${FILE_HASH}" class="chip ${SEVERITY_CLASS}">${FILENAME}</a>`
   - FILE_HASH should be a URL-safe hash of the file path

2. **FILE_CARDS**: For each file with findings, generate a file card:
   ```html
   <article class="file-card" id="file-${FILE_HASH}">
     <header class="file-head">
       <span class="file-path">${FILE_PATH}</span>
       <span class="risk-tag ${SEVERITY_CLASS}">${HIGHEST_SEVERITY}</span>
     </header>
     <div class="comments">
       <!-- For each finding in this file -->
       <div class="bubble ${SEVERITY}">
         <span class="severity">${SEVERITY}</span>
         <strong>${TITLE}</strong>
         <p>${DESCRIPTION}</p>
         <div class="location">Lines ${LINE_START}-${LINE_END}</div>
         <div class="agent">Found by: ${AGENT_NAME}</div>
       </div>
     </div>
   </article>
   ```

4. **Report success**:
```
HTML report generated: .omnibus-review/report_${TIMESTAMP}.html

Open in browser to view the interactive report.
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
