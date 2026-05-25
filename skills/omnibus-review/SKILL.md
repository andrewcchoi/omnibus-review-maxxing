---
name: omnibus-review
description: Use this skill when the user asks for "comprehensive review", "omnibus review", "full code review", "review with fixing", "iterative code review", "review all aspects", "combined review", or needs guidance on combining multiple review types into an effective workflow with optional iterative fixing via Ralph Loop.
version: 1.0.0
---

## MANDATORY: Read Reference Documents First

**BEFORE orchestrating the review, you MUST use the Read tool to read these documents:**

1. `docs/workflow-diagram.html` — Defines the 4-phase execution sequence.
   You MUST NOT begin dispatch without understanding the workflow.

2. `docs/severity-guide.html` — Defines severity classification rules and thresholds.
   You MUST NOT aggregate findings without consistent severity standards.

3. `docs/agent-overview.html` — Defines each specialist agent's responsibilities.
   You MUST NOT dispatch agents without understanding their focus areas.

4. `docs/output-templates.html` — Specifies JSON schema and report structure.
   You MUST NOT format output without conforming to this specification.

5. `references/checklist.html` — Pre-review preparation and post-review actions.
   You MUST NOT skip validation steps defined in the checklist.

6. `references/cwe-quick-ref.html` — Security vulnerability classifications.
   You MUST reference correct CWE IDs for security findings.

**Why this is mandatory:** These documents define the standards for severity classification, output format, and workflow execution. Inconsistent severity or malformed output will compromise the aggregated report quality. Reading these documents is not optional.

# Omnibus Review Skill

Orchestrates a comprehensive code review by dispatching 6 specialized review agents in parallel, aggregating their findings, and optionally entering an iterative fixing loop.

## When to Use

Trigger this skill when the user requests:

- "comprehensive review"
- "omnibus review" 
- "full code review"
- "review with fixing"
- "iterative code review"
- "review all aspects"
- "combined review"
- Multiple review types at once (security + correctness + testing, etc.)
- A thorough analysis covering all quality dimensions

## Usage

```bash
# Basic comprehensive review
/omnibus-review

# Review with automatic fixing (Ralph Loop)
/omnibus-review --fix

# Custom fixing iterations
/omnibus-review --fix --max-iterations 6

# Review specific files or patterns
/omnibus-review src/services/**/*.py

# Combine with fixing
/omnibus-review --fix backend/src/controllers/
```

## How It Works

The omnibus review executes in phases:

### Review Mode (default)
1. **Dispatch Phase**: Spawns 6 parallel review agents, each running Opus 4.5 with ultrathink mode
2. **Aggregation Phase**: Collects and consolidates findings into structured JSON
3. **Formatting Phase**: Transforms aggregated data into human-readable report with severity-based grouping

### Fix Mode (`--fix` flag)
4. **Planning Phase**: Groups findings by file, generates YAML fix plans
5. **Fix Phase**: Spawns parallel `omnibus-fixer` subagents (one per file)
6. **Validation Phase**: Spawns parallel `omnibus-validator` subagents (verify fixes)
7. **Re-Review Phase**: Runs review agents on modified files, loops if issues remain

## The 8 Agents

### Review Agents (6)
Each agent focuses on a specific quality dimension:

1. **Correctness Agent**: Logic errors, race conditions, data consistency, algorithmic correctness
2. **Security Agent**: Vulnerabilities (OWASP Top 10), injection flaws, auth/authz issues, crypto misuse
3. **Compliance Agent**: CLAUDE.md guidelines, architecture patterns, coding standards
4. **Testing Agent**: Test coverage gaps, missing edge cases, test quality, fixture issues
5. **Error Handling Agent**: Exception handling, error propagation, logging, graceful degradation
6. **Quality Agent**: Code style, maintainability, documentation, performance, best practices

### Fix Agents (2)
7. **Omnibus Fixer**: Applies COMPLETE fixes per file following fix plan, documents divergence
8. **Omnibus Validator**: Verifies fixes match plan, catches shortcuts, flags regressions

All review agents use:
- **Model**: Claude Opus 4.5
- **Mode**: Ultrathink (extended reasoning)
- **Output**: Structured JSON findings with severity (critical/high/medium/low), confidence (0-100), file paths, and remediation

Fix agents use:
- **Model**: Claude Opus 4.5
- **Context**: Fresh (isolated from review phase)
- **Input**: Single file + YAML fix plan
- **Output**: Updated plan with status and validation report

## Parallel Fix Architecture

When `--fix` is enabled:

1. **No confirmation prompts** - proceeds automatically with all fixes
2. **Complete fixes only** - no shortcuts, must address root cause
3. **Architecture alignment** - fixes must fit existing codebase patterns
4. **Context isolation** - each fixer/validator starts fresh (no compaction)
5. **Divergence tracking** - deviations require documented reasons
6. **Validation layer** - validators catch incomplete or incorrect fixes

```
Findings → Group by file → 
    Parallel Fixers (one per file) →
    Parallel Validators (one per file) →
    Re-Review → Loop if CRITICAL/HIGH remain
```

Early exit phrase: `QUANTUM_EIGENSTATE_CRYSTALLIZED_OMEGA`

Benefits:
- Scales to any number of files
- No context bloat during fix loop
- Each agent has minimal, focused context
- Validation catches mistakes before re-review

## Output Format

The skill produces:

- **JSON Report**: `omnibus-review-findings.json` with structured data for programmatic access
- **Human Report**: `omnibus-review-report.md` with severity-grouped findings, stats, and recommendations
- **Console Summary**: Counts by agent, severity distribution, top issues

## Examples

**Scenario 1: Pre-release comprehensive check**
```bash
/omnibus-review --fix
```
Reviews entire diff, fixes all findings iteratively, exits when confidence >= 80.

**Scenario 2: Security and correctness focus**
```bash
/omnibus-review backend/src/auth/
```
All 6 agents run, but you can manually focus on security/correctness findings in the report.

**Scenario 3: Post-PR review before merge**
```bash
/omnibus-review --fix --max-iterations 2
```
Quick review with limited fixing iterations for time-sensitive merges.

## Notes

- All agents run in parallel for speed (typically completes in 2-3 minutes)
- Findings are deduplicated across agents
- Confidence scores indicate reliability of each finding
- Ralph Loop respects git safety protocols (no force push, no --no-verify)
- Reports persist in working directory for future reference
