# Omnibus Review Maxxing

A comprehensive Claude Code review plugin combining 6 specialized agents with Ralph Loop iterative fixing.

## Features

- **6 Specialized Review Agents** - Each focused on a specific domain
- **Opus + Ultrathink** - Maximum reasoning depth for all reviews
- **JSON Output** - Structured, aggregatable findings
- **Ralph Loop Integration** - Iterative fixing until issues resolved
- **Rich HTML Documentation** - Visual workflows, severity guides, CWE references

## Quick Start

```bash
# Basic review (report only)
/omnibus-review

# Review specific files
/omnibus-review src/api/ src/models/

# Generate interactive HTML report
/omnibus-review --html

# Review with iterative fixing (max 4 iterations)
/omnibus-review --fix

# Use Opus for fixing (default: Sonnet)
/omnibus-review --fix --opus
```

## The 6 Agents

| Agent | Focus | Color |
|-------|-------|-------|
| **correctness-auditor** | Bugs, logic errors, null handling, race conditions | 🔴 Red |
| **security-sentinel** | OWASP vulnerabilities, injection, auth flaws | 🔴 Red |
| **claude-md-compliance** | CLAUDE.md guideline violations | 🟡 Yellow |
| **test-coverage-analyzer** | Test gaps, missing edge cases, weak assertions | 🟢 Green |
| **silent-failure-hunter** | Empty catches, swallowed errors, missing logging | 🟡 Yellow |
| **code-quality-reviewer** | Duplication, complexity, naming, patterns | 🔵 Blue |

## Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                    OMNIBUS REVIEW WORKFLOW                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Phase 1: SCOPE          Determine files to review              │
│           ↓              (git diff or explicit paths)           │
│                                                                 │
│  Phase 2: DISPATCH       Launch 6 agents in parallel            │
│           ↓              (all use Opus + ultrathink)            │
│                                                                 │
│  Phase 3: AGGREGATE      Merge findings, filter <80 confidence  │
│           ↓              Deduplicate, sort by severity          │
│                                                                 │
│  Phase 4: REPORT/FIX     Output report OR enter Ralph Loop      │
│                          Fix CRITICAL→HIGH until resolved       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Severity Levels

| Severity | Color | Threshold | Action |
|----------|-------|-----------|--------|
| **CRITICAL** | 🔴 `#dc3545` | Confidence ≥80 | Must fix before merge |
| **HIGH** | 🟠 `#fd7e14` | Confidence ≥80 | Should fix before merge |
| **MEDIUM** | 🟡 `#ffc107` | Confidence ≥80 | Consider fixing |
| **LOW** | 🔵 `#0d6efd` | Confidence ≥80 | Nice to have |

## Ralph Loop Integration

When `--fix` is enabled, the review enters an iterative loop:

1. Run comprehensive review (6 agents)
2. Fix CRITICAL issues first, then HIGH
3. Re-run review to verify fixes
4. Repeat until no CRITICAL/HIGH issues remain OR max iterations (default: 4)

**Early Exit Phrase:** `QUANTUM_EIGENSTATE_CRYSTALLIZED_OMEGA`

## Installation

### Option 1: Clone directly
```bash
git clone git@github.com:andrewcchoi/omnibus-review-maxxing.git ~/.claude/plugins/omnibus-review-maxxing
```

### Option 2: Add to settings
Add to your `.claude/settings.json`:
```json
{
  "plugins": ["https://github.com/andrewcchoi/omnibus-review-maxxing"]
}
```

## Documentation

Rich HTML documentation is included in the plugin:

| Document | Description |
|----------|-------------|
| [README.html](README.html) | Main documentation with architecture diagram |
| [docs/workflow-diagram.html](docs/workflow-diagram.html) | Visual 4-phase workflow |
| [docs/severity-guide.html](docs/severity-guide.html) | Color-coded severity classification |
| [docs/agent-overview.html](docs/agent-overview.html) | 6 agents with responsibilities |
| [docs/output-templates.html](docs/output-templates.html) | Output format examples |
| [references/checklist.html](references/checklist.html) | Pre/post review checklists |
| [references/cwe-quick-ref.html](references/cwe-quick-ref.html) | Security CWE reference |

## Commands

| Command | Description |
|---------|-------------|
| `/omnibus-review` | Run comprehensive review |
| `/cancel-omnibus` | Cancel active review loop |

## Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `--fix` | Enable Ralph Loop iterative fixing | Off |
| `--html` | Generate interactive HTML report with risk maps | Off |
| `--max-iterations N` | Maximum fix iterations | 4 |
| `--opus` | Use Opus for fixing (review always uses Opus) | Sonnet |
| `[files...]` | Specific files/directories to review | git diff |

## HTML Output

With `--html`, the review generates a self-contained HTML report at `.omnibus-review/report_[timestamp].html`:

- **Risk map** - Clickable severity chips for quick navigation to files
- **File cards** - Each file with its findings grouped
- **Severity indicators** - Color-blind accessible (icons + colors)
- **Comment bubbles** - Findings with severity, description, location
- **Next steps** - Actionable checklist

Open the HTML file in any browser. No build step or dependencies required.

## Output Format

All agents output structured JSON:

```json
{
  "agent": "security-sentinel",
  "findings": [
    {
      "severity": "CRITICAL",
      "confidence": 95,
      "location": { "file": "src/api.py", "line_start": 42 },
      "title": "SQL Injection vulnerability",
      "description": "User input directly concatenated into SQL query",
      "fix": { "suggestion": "Use parameterized queries" }
    }
  ],
  "summary": { "critical": 1, "high": 0, "medium": 2, "low": 1 }
}
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

Built with Claude Code using subagent-driven development.
