<!-- omnibus-review:config:start -->
## Code Review Guidelines (Omnibus Review Defaults)

These guidelines are used by the omnibus-review plugin's 6 specialized agents.
Customize these sections to match your project's standards.

### Correctness Standards
<!-- Used by: correctness-auditor agent -->
- Verify logic handles all branches and edge cases
- Check async operations use proper await/error handling
- Validate data consistency across operations
- Ensure thread safety for concurrent operations
- Check algorithm correctness for boundary conditions

### Security Requirements
<!-- Used by: security-sentinel agent -->
- Validate ALL user input before processing
- Use parameterized queries exclusively (no string concatenation for SQL)
- Never log sensitive data: passwords, tokens, API keys, PII
- Implement rate limiting on public endpoints
- Use secure defaults for all configurations
- Validate file paths to prevent directory traversal
- Sanitize output to prevent XSS

### Architecture Patterns
<!-- Used by: claude-md-compliance agent -->
- Follow consistent layering: Controllers/Handlers -> Services -> Repositories -> Models
- Keep business logic out of controllers/handlers
- Use dependency injection for testability
- Separate concerns: data access, business logic, presentation
- Follow established project conventions for file organization

### Testing Requirements
<!-- Used by: test-coverage-analyzer agent -->
- All new features require unit tests
- Critical paths require integration tests
- Test edge cases and error conditions
- Maintain test independence (no shared mutable state)
- Use descriptive test names that explain the scenario

### Error Handling Standards
<!-- Used by: silent-failure-hunter agent -->
- Never swallow exceptions silently
- Log errors with sufficient context for debugging
- Provide meaningful error messages to users (without leaking internals)
- Use appropriate error types/codes
- Ensure cleanup runs in finally blocks
- Validate external service responses

### Code Quality Guidelines
<!-- Used by: code-quality-reviewer agent -->
- Functions should do one thing well (single responsibility)
- Avoid deep nesting (max 3-4 levels)
- Use descriptive names for variables, functions, and classes
- Document non-obvious behavior and "why" not "what"
- Keep functions under 50 lines when possible
- Remove dead code and unused imports

### DO NOT (Prohibited Patterns)
- Commit secrets or credentials to version control
- Disable security features without documented approval
- Ignore compiler/linter warnings without justification
- Use deprecated APIs
- Catch generic exceptions without re-throwing
- Trust client-side validation exclusively
<!-- omnibus-review:config:end -->
