# WPF Release Readiness Checklist

Use this checklist before splitting WPF into its own repository or announcing broader use.

## 1. Product Readiness

- [ ] At least one flagship example is stable and runnable end to end.
- [ ] At least two additional examples cover common UI patterns.
- [ ] Known breaking behavior is documented in README or Docs.
- [ ] Expected PowerShell 5 behavior is verified on Windows.

## 2. Documentation Readiness

- [ ] README gives a clear first-run path and realistic scope.
- [ ] Keyword and style docs match current behavior.
- [ ] The "When This Is Not a Fit" section reflects current limits.
- [ ] Maintainer docs are separated from user-facing docs.

## 3. Quality Readiness

- [ ] Module imports cleanly from a fresh session.
- [ ] At least one smoke test path is documented and repeatable.
- [ ] Error messages are actionable for common failures.
- [ ] No known blocker bugs remain for primary examples.
- [ ] Test runs in Windows PowerShell 5.1 and PowerShell 7 explicitly use Pester 5.7.1 or newer.

For PS5 compatibility and Pester policy details, use the maintainer skill at `.github/skills/wpf-ps5-test-compatibility/SKILL.md`.

## 4. Backlog and Issue Hygiene

- [ ] Durable backlog items are tracked as issues, not only markdown notes.
- [ ] Issues are labeled enough to identify blocker vs enhancement.
- [ ] Top priority work for the first standalone release is scoped.

## 5. Repository Split Readiness

- [ ] Extraction method is chosen and documented.
- [ ] Required repo-root files for the new repo are identified.
- [ ] Post-split links and traceability notes are prepared.
- [ ] Migration dry run was completed at least once.

## Split Trigger Template

Use this as a concrete go/no-go gate. Adjust numbers if needed.

- [ ] 3 stable examples.
- [ ] Top 5 priority issues closed.
- [ ] README and docs reviewed in a clean environment.
- [ ] Dry-run split validated from extracted branch/worktree.

If all checks above pass, proceed with the migration steps in `RepositoryMigrationPlan.md`.
