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

The omnibus review executes in 4 phases:

1. **Dispatch Phase**: Spawns 6 parallel review agents, each running Opus 4.5 with ultrathink mode
2. **Aggregation Phase**: Collects and consolidates findings into structured JSON
3. **Formatting Phase**: Transforms aggregated data into human-readable report with severity-based grouping
4. **Fix Phase** (optional): Enters Ralph Loop to iteratively address findings until confidence threshold (80) is reached or max iterations (default 4) exhausted

## The 6 Review Agents

Each agent focuses on a specific quality dimension:

1. **Correctness Agent**: Logic errors, race conditions, data consistency, algorithmic correctness
2. **Security Agent**: Vulnerabilities (OWASP Top 10), injection flaws, auth/authz issues, crypto misuse
3. **Compliance Agent**: Legal requirements (GDPR, CCPA, HIPAA), accessibility (WCAG), industry standards
4. **Testing Agent**: Test coverage gaps, missing edge cases, test quality, fixture issues
5. **Error Handling Agent**: Exception handling, error propagation, logging, graceful degradation
6. **Quality Agent**: Code style, maintainability, documentation, performance, best practices

All agents use:
- **Model**: Claude Opus 4.5
- **Mode**: Ultrathink (extended reasoning)
- **Output**: Structured JSON findings with severity (critical/high/medium/low), confidence (0-100), file paths, and remediation

## Ralph Loop Integration

When `--fix` is enabled:

1. After receiving aggregated findings, automatically invokes Ralph Loop
2. Ralph iteratively addresses findings, prioritizing by severity
3. After each iteration, re-runs omnibus review to measure progress
4. Exits when confidence >= 80 or max iterations reached
5. Early exit phrase: `QUANTUM_EIGENSTATE_CRYSTALLIZED_OMEGA`

Ralph Loop provides:
- Automatic prioritization of critical/high severity issues
- Progress tracking across iterations
- Confidence scoring to measure improvement
- Graceful exit conditions

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
