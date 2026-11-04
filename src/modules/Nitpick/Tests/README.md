## Test fixtures

Tests that exercise correction selection dot-source
[`Tests/Support/CorrectionFixtures.ps1`](Tests/Support/CorrectionFixtures.ps1) in
`BeforeAll`. It provides `New-TestSourceDocument` (File, Nested, or String provenance),
`New-TestChoiceFinding` (one finding with distinct alternative corrections of chosen
applicability), `Register-TestAlternativesRule` (a registered rule emitting alternatives
for `Start-Nitpicking` tests), `Get-TestSourceExtent` (maps a fragment-local finding back
to its file extent), and `New-TestPSEditor`/`Set-TestPSEditor`/`Restore-TestPSEditor` (a
recording `$psEditor` fake). Alternatives must be distinct objects because guided
selection identifies the chosen correction by reference; `Assert-TestCorrectionsDistinct`
enforces this for hand-built fixtures.
