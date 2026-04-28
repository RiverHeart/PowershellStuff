# WPF DSL Contribution Checklist

Use this checklist for any DSL-facing change.

## Code

- [ ] Updated or added keyword/helper implementation
- [ ] Preserved trailing scriptblock and $this conventions
- [ ] Confirmed parent-child auto-attach behavior

## Exports

- [ ] Updated src/modules/WPF/WPF.psd1 if public function surface changed

## Tests

- [ ] Added or updated tests in src/modules/WPF/Tests
- [ ] Ran:

```powershell
Invoke-Pester -Path "src/modules/WPF/Tests" -Output Detailed
```

## Documentation

- [ ] Updated src/modules/WPF/Docs/KeywordReference.md
- [ ] Updated other impacted docs (theme/style/examples)
- [ ] Confirmed README links include any new docs pages

## Final Review

- [ ] Verified no parse/analyzer errors in changed files
- [ ] Summarized compatibility impacts (if any)
