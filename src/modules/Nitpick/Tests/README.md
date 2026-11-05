## Test fixtures

Tests that exercise correction selection dot-source
[`Tests/Support/CorrectionFixtures.ps1`](Tests/Support/CorrectionFixtures.ps1) in
`BeforeAll`. It provides `New-TestSourceDocument` (File, Nested, or String provenance),
`New-TestChoiceFinding` (one finding with distinct alternative corrections of chosen
applicability), `Register-TestAlternativesRule` (a registered rule emitting alternatives
for `Start-Nitpicking` tests), and `New-TestPSEditor`/`Set-TestPSEditor`/`Restore-TestPSEditor` (a
recording `$psEditor` fake). Alternatives must be distinct objects because guided
selection identifies the chosen correction by reference; `Assert-TestCorrectionsDistinct`
enforces this for hand-built fixtures.
Findings already carry snapshot-absolute extents, including for Nested fixtures;
navigation assertions can compare them directly with the independently parsed source AST.

## Suppressing WhatIf

For calls routed through `Should-Process`, set `WHATIF__QUIET` to `'True'` while
testing `-WhatIf`, and restore its previous value afterward. This suppresses the
host output while preserving a false decision for WhatIf. Restore the environment
variable in `AfterAll` when setting it in `BeforeAll` to avoid leaking test state.
When WhatIf is inactive, quiet mode still honors `-Confirm` and
`$ConfirmPreference`; it does not automatically approve writes.

Worth documenting, the following code block presents an interesting way of suppressing WhatIf output by overriding the `$PSCmdlet.ShouldProcess` method at runtime using a breakpoint action.

```powershell
$Breakpoint = Set-PSBreakpoint `
    -Script $Command.ScriptBlock.File `
    -Line $ShouldProcessCall.Extent.StartLineNumber `
    -Action {
        (Get-Variable -Name PSCmdlet -Scope 1).Value |
        Add-Member `
            -MemberType ScriptMethod `
            -Name ShouldProcess `
            -Value { $false } -Force
    }

try {
    Resolve-NitpickTargetCorrection `
        -Document $Fixture.Document `
        -Finding $Fixture.Findings `
        -Rule $Fixture.Rules `
        -FixMode Apply `
        -Confirm:$false
} finally {
    $Breakpoint | Remove-PSBreakpoint
}
```

## Simulating a declined confirmation

Quiet WhatIf and a declined confirmation are different cases. `-Confirm:$false`
disables confirmation prompts; it does not decline an operation. Mock the wrapper
to return false when testing a decline without `-WhatIf`:

```powershell
Mock Should-Process -ModuleName Nitpick { $false }
```

This replaces the breakpoint that previously overrode `$PSCmdlet.ShouldProcess`.
Keep WhatIf tests unmocked so they exercise the wrapper's WhatIf behavior.
