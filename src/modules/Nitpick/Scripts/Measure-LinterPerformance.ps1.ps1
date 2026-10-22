<#
.SYNOPSIS
    Compares native Nitpick with PSScriptAnalyzer hosting the same Nitpick rule.

.DESCRIPTION
    Stages tracked production .ps1 files locally, checks diagnostic parity, and
    alternates warmed timings. Fixes are exercised only on disposable fixtures.
    Files are never modified. Dependencies must already be installed.
    Scope mismatches invalidate corpus speedup claims. Parser diagnostics are
    included in total counts but excluded from rule parity. Import timings are
    single observations, not statistically sampled cold-start measurements.

.EXAMPLE
    .\Measure-LinterPerformance.ps1 -WorkingDirectory /path/to/working/directory
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $WorkingDirectory,

    [ValidateRange(3, 15)]
    [int] $Iterations = 5
)

$ErrorActionPreference = 'Stop'
$WorkingDirectory = (Resolve-Path -LiteralPath $WorkingDirectory).Path
$Manifest = Join-Path $WorkingDirectory 'src\modules\Nitpick\Nitpick.psd1'
$ImportTimes = foreach ($Module in @($Manifest, 'PSScriptAnalyzer')) {
    $Watch = [System.Diagnostics.Stopwatch]::StartNew()
    Import-Module $Module -ErrorAction Stop
    $Watch.Stop()
    [pscustomobject]@{
        Module = $Module
        Milliseconds = [math]::Round($Watch.Elapsed.TotalMilliseconds, 2)
    }
}

function Invoke-Engine {
    param(
        [string] $Engine,
        [string] $Rule,
        [string] $Source,
        [string] $Path
    )

    if ($Engine -eq 'Nitpick') {
        $Parameters = @{ IncludeRule = $Rule; Output = 'Object'; NoSummary = $true }
        if ($Path) { $Parameters.Path = $Path } else { $Parameters.Script = $Source }
        Start-Nitpicking @Parameters
    } else {
        $Parameters = @{
            CustomRulePath = $Manifest
            IncludeRule = "Test-$Rule"
            Settings = @{}
        }
        if ($Path) {
            $Parameters.Path = $Path
            $Parameters.Recurse = $true
        } else {
            $Parameters.ScriptDefinition = $Source
        }
        Invoke-ScriptAnalyzer @Parameters
    }
}

function Get-FindingKey {
    param([object] $Finding)

    $Extent = if ($Finding.ViolationExtent) { $Finding.ViolationExtent } else { $Finding.Extent }
    '{0}|{1}|{2}|{3}|{4}|{5}' -f $Extent.File, $Finding.RuleName, $Finding.Severity,
        $Extent.StartOffset, $Extent.EndOffset, $Finding.Message
}

function Get-Median {
    param([double[]] $Values)

    $Sorted = @($Values | Sort-Object)
    if ($Sorted.Count % 2) { return $Sorted[[int][math]::Floor($Sorted.Count / 2)] }
    return ($Sorted[$Sorted.Count / 2 - 1] + $Sorted[$Sorted.Count / 2]) / 2
}

$Cases = @(
    @{ Name = 'Top-level'; Rule = 'UseIsNotOperator'; Source = 'if (-not ($x -is [int])) {}' }
    @{ Name = 'Function body'; Rule = 'UseIsNotOperator'; Source = 'function f { if (-not ($x -is [int])) {} }' }
    @{ Name = 'Nested script block'; Rule = 'UseIsNotOperator'; Source = '& { if (-not ($x -is [int])) {} }' }
    @{ Name = 'Interpolation'; Rule = 'UseIsNotOperator'; Source = '"result: $(-not ($x -is [int]))"' }
    @{ Name = 'Already compliant'; Rule = 'UseIsNotOperator'; Source = 'if ($x -isnot [int]) {}' }
    @{ Name = 'Top-level parameter'; Rule = 'AvoidParameterAttributeBool'; Source = 'param([Parameter(Mandatory=$true)] [string] $Name)' }
    @{ Name = 'Function parameter'; Rule = 'AvoidParameterAttributeBool'; Source = 'function f { param([Parameter(Mandatory=$true)] [string] $Name) }' }
)
$Parity = foreach ($Case in $Cases) {
    $Native = @(Invoke-Engine -Engine Nitpick -Rule $Case.Rule -Source $Case.Source)
    $Analyzer = @(Invoke-Engine -Engine ScriptAnalyzer -Rule $Case.Rule -Source $Case.Source)
    [pscustomobject]@{
        Case = $Case.Name
        Rule = $Case.Rule
        Nitpick = $Native.Count
        ScriptAnalyzer = $Analyzer.Count
    }
}

$FixtureRoot = Join-Path $PSScriptRoot ('nitpick-evaluation-' + [guid]::NewGuid().ToString('N'))
[void] [System.IO.Directory]::CreateDirectory($FixtureRoot)
try {
    $CorpusRoot = Join-Path $FixtureRoot 'corpus'
    [void] [System.IO.Directory]::CreateDirectory($CorpusRoot)

    $Tracked = @(& git -C $WorkingDirectory ls-files -- 'src/modules/*.ps1' 'src/scripts/*.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'git ls-files failed.' }

    $Tracked = @($Tracked | Where-Object { $_ -notmatch '(?i)/tests/' })
    if ($Tracked.Count -eq 0) { throw 'No tracked production .ps1 files found.' }

    $Bytes = 0L
    foreach ($RelativePath in $Tracked) {
        $RelativePath = $RelativePath.Replace('/', '\')
        $Original = Join-Path $WorkingDirectory $RelativePath
        $Staged = Join-Path $CorpusRoot $RelativePath
        [void] [System.IO.Directory]::CreateDirectory((Split-Path -Parent $Staged))
        [System.IO.File]::Copy($Original, $Staged)
        $Bytes += (Get-Item -LiteralPath $Original).Length
    }

    $Native = @(Invoke-Engine -Engine Nitpick -Rule UseIsNotOperator -Path $CorpusRoot)
    $Analyzer = @(Invoke-Engine -Engine ScriptAnalyzer -Rule UseIsNotOperator -Path $CorpusRoot)
    $NativeKeys = @($Native | Where-Object RuleName -eq UseIsNotOperator | ForEach-Object { Get-FindingKey $_ })
    $AnalyzerKeys = @($Analyzer | Where-Object RuleName -eq UseIsNotOperator | ForEach-Object { Get-FindingKey $_ })
    $NativeSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($Key in $NativeKeys) { [void] $NativeSet.Add($Key) }
    $AnalyzerSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($Key in $AnalyzerKeys) { [void] $AnalyzerSet.Add($Key) }

    $Timings = [System.Collections.Generic.List[object]]::new()
    for ($Index = 0; $Index -lt $Iterations; $Index++) {
        $Order = if ($Index % 2) { @('ScriptAnalyzer', 'Nitpick') } else { @('Nitpick', 'ScriptAnalyzer') }
        foreach ($Engine in $Order) {
            $Watch = [System.Diagnostics.Stopwatch]::StartNew()
            $Results = @(Invoke-Engine -Engine $Engine -Rule UseIsNotOperator -Path $CorpusRoot)
            $Watch.Stop()
            $Timings.Add([pscustomobject]@{
                Engine = $Engine
                Milliseconds = $Watch.Elapsed.TotalMilliseconds
                Findings = $Results.Count
            })
        }
    }
    $TimingSummary = foreach ($Engine in @('Nitpick', 'ScriptAnalyzer')) {
        $Samples = @($Timings | Where-Object Engine -eq $Engine)
        [pscustomobject]@{
            Engine = $Engine
            MedianMilliseconds = [math]::Round((Get-Median $Samples.Milliseconds), 2)
            SamplesMilliseconds = @($Samples | ForEach-Object { [math]::Round($_.Milliseconds, 2) })
            Findings = $Samples[0].Findings
        }
    }

    $Density = foreach ($Count in @(10, 100, 300)) {
        $Source = ('-not ($x -is [int])' + [Environment]::NewLine) * $Count
        foreach ($Engine in @('Nitpick', 'ScriptAnalyzer')) {
            [void] @(Invoke-Engine -Engine $Engine -Rule UseIsNotOperator -Source $Source)
            $Samples = @()
            $ResultCount = 0
            for ($Index = 0; $Index -lt 3; $Index++) {
                $Watch = [System.Diagnostics.Stopwatch]::StartNew()
                $Results = @(Invoke-Engine -Engine $Engine -Rule UseIsNotOperator -Source $Source)
                $Watch.Stop()
                $Samples += $Watch.Elapsed.TotalMilliseconds
                $ResultCount = $Results.Count
            }
            if ($ResultCount -ne $Count) { throw "$Engine returned $ResultCount findings; expected $Count." }
            [pscustomobject]@{
                Violations = $Count
                Engine = $Engine
                MedianMilliseconds = [math]::Round((Get-Median $Samples), 2)
            }
        }
    }

    $FixPath = Join-Path $FixtureRoot 'fix.ps1'
    $Source = "# fixture`r`nif (-not (`$x -is [int])) {}`r`n"
    $Encoding = [System.Text.UTF8Encoding]::new($true)
    [System.IO.File]::WriteAllText($FixPath, $Source, $Encoding)
    $Original = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($FixPath))

    $Preview = @(Start-Nitpicking -Path $FixPath -IncludeRule UseIsNotOperator -Fix -Preview -Output Object -NoSummary) |
        Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }

    $PreviewUnchanged = $Original -ceq [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($FixPath))

    $Applied = @(Start-Nitpicking -Path $FixPath -IncludeRule UseIsNotOperator -Fix -Confirm:$false -Output Object -NoSummary) |
        Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }

    $Second = @(Start-Nitpicking -Path $FixPath -IncludeRule UseIsNotOperator -Fix -Confirm:$false -Output Object -NoSummary) |
        Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }

    $Expected = "# fixture`r`nif ( (`$x -isnot [int])) {}`r`n"
    $ExpectedBytes = [byte[]] (@($Encoding.GetPreamble()) + @($Encoding.GetBytes($Expected)))
    $BytesPreserved = [Convert]::ToBase64String($ExpectedBytes) -ceq
        [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($FixPath))

    if (-not $PreviewUnchanged -or $Applied.Application.Status -ne 'Written' -or
        $Second.Proposal.Status -ne 'NoChanges' -or -not $BytesPreserved -or
        $Applied.Report.EffectiveFindings.Count -ne 0 -or
        $Applied.Report.FindingsWithCommittedCorrections.Count -ne 1) {
        throw 'Preview/apply/idempotence checks failed.'
    }

    [pscustomobject]@{
        PowerShell = $PSVersionTable.PSVersion.ToString()
        Edition = $PSVersionTable.PSEdition
        ScriptAnalyzerVersion = (Get-Module PSScriptAnalyzer).Version.ToString()
        ImportTimes = @($ImportTimes)
        ScopeParity = @($Parity)
        Corpus = @{
            Files = $Tracked.Count
            Bytes = $Bytes
            NitpickRuleFindings = $NativeKeys.Count
            ScriptAnalyzerRuleFindings = $AnalyzerKeys.Count
            NativeParseErrors = @($Native | Where-Object RuleName -eq PowerShellParseError).Count
            ScriptAnalyzerParseErrors = @($Analyzer | Where-Object RuleName -eq ParseError).Count
            MissingFromNitpick = @($AnalyzerSet | Where-Object { -not $NativeSet.Contains($_) }).Count
            OnlyInNitpick = @($NativeSet | Where-Object { -not $AnalyzerSet.Contains($_) }).Count
        }
        WarmTimings = @($TimingSummary)
        DensityTimings = @($Density)
        Fix = @{
            PreviewUnchanged = $PreviewUnchanged
            BytesPreserved = $BytesPreserved
            Applied = $Applied.Application.Status -eq 'Written'
            AcceptedEdits = $Preview.Proposal.AcceptedCorrections.Count
            FindingsWithCommittedCorrections = $Applied.Report.FindingsWithCommittedCorrections.Count
            RemainingFindings = $Applied.Report.EffectiveFindings.Count
            SecondRun = $Second.Proposal.Status
            EffectiveText = $Applied.Report.EffectiveText
        }
    } | ConvertTo-Json -Depth 6
} finally {
    [System.IO.Directory]::Delete($FixtureRoot, $true)
}
