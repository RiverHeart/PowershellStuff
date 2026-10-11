BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../../Nitpick.psd1" -Force
}

BeforeDiscovery {
    $SeverityRanks = @{
        Information = 0
        Warning = 1
        Error = 2
    }
    $SeverityThresholdCases = foreach ($ErrorOn in 'Information', 'Warning', 'Error') {
        foreach ($FindingSeverity in 'Information', 'Warning', 'Error') {
            @{
                ErrorOn = $ErrorOn
                FindingSeverity = $FindingSeverity
                ShouldError = $SeverityRanks[$FindingSeverity] -ge $SeverityRanks[$ErrorOn]
            }
        }
    }
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Start-Nitpicking' {
    BeforeEach {
        InModuleScope Nitpick {
            (Get-NitpickRegistry).Nitpicks.Clear()
        }
        $SelectionFixture = $null
    }

    AfterEach {
        if ($SelectionFixture) {
            Remove-Item -LiteralPath $SelectionFixture -Recurse -Force
        }
    }

    It 'terminates before reading targets for an unmatched selector: <Selector>, Fix: <Fix>' -ForEach @(
        @{ Selector = 'Test-UseIsNotOperator'; Fix = $false }
        @{ Selector = 'MissingRule'; Fix = $false }
        @{ Selector = 'MissingRule'; Fix = $true }
    ) {
        Mock Get-ChildItem -ModuleName Nitpick { throw 'Targets must not be enumerated.' }
        Mock New-AstDocument -ModuleName Nitpick { throw 'Targets must not be parsed.' }
        Mock Save-AstDocument -ModuleName Nitpick { throw 'Targets must not be written.' }

        {
            Start-Nitpicking -Path $TestDrive -IncludeRule $Selector -Fix:$Fix -Output Object -ErrorAction Continue
        } | Should -Throw "*No Nitpick rules match the IncludeRule selector(s): $Selector.*"

        Should -Invoke Get-ChildItem -ModuleName Nitpick -Times 0 -Exactly -Scope It
        Should -Invoke New-AstDocument -ModuleName Nitpick -Times 0 -Exactly -Scope It
        Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly -Scope It
    }

    It 'reports every unmatched selector rather than executing a partial rule set' {
        Mock Test-UseIsNotOperator -ModuleName Nitpick { throw 'The valid rule must not run.' }
        Mock New-AstDocument -ModuleName Nitpick { throw 'Targets must not be parsed.' }
        $Output = [System.Collections.Generic.List[object]]::new()

        {
            Start-Nitpicking -Script '-not ($Value -is [int])' `
                -IncludeRule UseIsNotOperator,MissingRule,AnotherMissingRule,'Missing*' -Output Object |
                ForEach-Object { $Output.Add($_) }
        } | Should -Throw '*No Nitpick rules match the IncludeRule selector(s): MissingRule, AnotherMissingRule.*'

        $Output | Should -HaveCount 0
        Should -Invoke Test-UseIsNotOperator -ModuleName Nitpick -Times 0 -Exactly -Scope It
        Should -Invoke New-AstDocument -ModuleName Nitpick -Times 0 -Exactly -Scope It
    }

    It 'accepts matching wildcard, case-insensitive, and overlapping selectors' {
        $Results = @(Start-Nitpicking -Script '-not ($Value -is [int])' `
            -IncludeRule 'useisnotoperator','*IsNot*','Missing*' -Output Object -ErrorAction Stop)
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Summary.RuleCount | Should -Be 1
        $Summary.FindingCount | Should -Be 1
    }

    It 'terminates when wildcard rule selection leaves no eligible rules' {
        {
            Start-Nitpicking -Script {} -IncludeRule 'Missing*' -ErrorAction Continue
        } | Should -Throw 'No Nitpick rules were discovered or registered.*'
    }

    It 'allows an unmatched rule wildcard alongside a matching rule wildcard' {
        $Results = @(Start-Nitpicking -Script {} -IncludeRule '*IsNot*','Missing*' -Output Object)
        $Results | Should -HaveCount 1
        $Results[0].RuleCount | Should -Be 1
    }

    It 'terminates for a missing literal path before processing valid piped paths' {
        $TestDrive = (New-Item -Path (Join-Path $TestDrive ([guid]::NewGuid().ToString())) -ItemType Directory).FullName
        $SelectionFixture = $TestDrive
        $Valid = Join-Path $TestDrive 'Valid.ps1'
        Set-Content -LiteralPath $Valid -Value '$Value = 1'
        Mock New-AstDocument -ModuleName Nitpick { throw 'Analysis must not start.' }
        Mock Save-AstDocument -ModuleName Nitpick { throw 'Fixes must not start.' }
        {
            @($Valid, (Join-Path $TestDrive 'Missing.ps1')) |
                Start-Nitpicking -IncludeRule UseIsNotOperator -Fix -Output Object -ErrorAction Continue
        } | Should -Throw
        Should -Invoke New-AstDocument -ModuleName Nitpick -Times 0 -Exactly -Scope It
        Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly -Scope It
    }

    It 'allows empty directories and wildcard paths alongside valid piped paths' {
        $TestDrive = (New-Item -Path (Join-Path $TestDrive ([guid]::NewGuid().ToString())) -ItemType Directory).FullName
        $SelectionFixture = $TestDrive
        $Empty = New-Item -Path (Join-Path $TestDrive 'Empty') -ItemType Directory
        $Valid = Join-Path $TestDrive 'Valid.ps1'
        Set-Content -LiteralPath $Valid -Value '$Value = 1'
        $Results = @(
            @($Empty.FullName, (Join-Path $TestDrive 'Missing*.ps1'), $Valid) |
                Start-Nitpicking -IncludeRule UseIsNotOperator -Output Object -ErrorAction Stop
        )
        $Results | Should -HaveCount 1
        $Results[0].TargetCount | Should -Be 1
    }

    It 'terminates without a summary when no files remain: <Mode>' -ForEach @(
        @{ Mode = 'empty directory' }
        @{ Mode = 'unmatched wildcard' }
        @{ Mode = 'filter' }
        @{ Mode = 'include' }
        @{ Mode = 'exclude' }
        @{ Mode = 'directory named like a script' }
    ) {
        $TestDrive = (New-Item -Path (Join-Path $TestDrive ([guid]::NewGuid().ToString())) -ItemType Directory).FullName
        $SelectionFixture = $TestDrive
        $Parameters = @{ Path = $TestDrive; IncludeRule = 'UseIsNotOperator'; Output = 'Object' }
        if ($Mode -eq 'directory named like a script') {
            $null = New-Item -Path (Join-Path $TestDrive 'Fake.ps1') -ItemType Directory
        } elseif ($Mode -ne 'empty directory' -and $Mode -ne 'unmatched wildcard') {
            Set-Content -LiteralPath (Join-Path $TestDrive 'Valid.ps1') -Value '$Value = 1'
        }
        switch ($Mode) {
            'unmatched wildcard' { $Parameters.Path = Join-Path $TestDrive 'Missing*.ps1' }
            'filter' { $Parameters.Filter = '*.psm1' }
            'include' { $Parameters.IncludePath = '*Missing*' }
            'exclude' { $Parameters.ExcludePath = '*' }
        }
        Mock New-AstDocument -ModuleName Nitpick { throw 'Analysis must not start.' }
        $Output = [System.Collections.Generic.List[object]]::new()
        {
            Start-Nitpicking @Parameters | ForEach-Object { $Output.Add($_) }
        } | Should -Throw 'No file targets remain*'
        $Output | Should -HaveCount 0
        Should -Invoke New-AstDocument -ModuleName Nitpick -Times 0 -Exactly -Scope It
    }

    It 'validates literal include paths across the invocation before exclusions' {
        $TestDrive = (New-Item -Path (Join-Path $TestDrive ([guid]::NewGuid().ToString())) -ItemType Directory).FullName
        $SelectionFixture = $TestDrive
        $First = Join-Path $TestDrive 'First.ps1'
        $Second = Join-Path $TestDrive 'Second.ps1'
        Set-Content -LiteralPath $First -Value '$Value = 1'
        Set-Content -LiteralPath $Second -Value '$Value = 2'
        $Results = @(
            @($First, $Second) | Start-Nitpicking -IncludeRule UseIsNotOperator `
                -IncludePath $First,$Second,'*Missing*' -ExcludePath $First,'*Absent*' -Output Object
        )
        $Results | Should -HaveCount 1
        $Results[0].TargetCount | Should -Be 1
    }

    It 'rejects unmatched literal include paths even when other files match' {
        $TestDrive = (New-Item -Path (Join-Path $TestDrive ([guid]::NewGuid().ToString())) -ItemType Directory).FullName
        $SelectionFixture = $TestDrive
        $Valid = Join-Path $TestDrive 'Valid.ps1'
        $Missing = Join-Path $TestDrive 'Missing.ps1'
        Set-Content -LiteralPath $Valid -Value '$Value = 1'
        Mock New-AstDocument -ModuleName Nitpick { throw 'Analysis must not start.' }
        {
            Start-Nitpicking -Path $TestDrive -IncludeRule UseIsNotOperator `
                -IncludePath $Valid,$Missing -Output Object
        } | Should -Throw '*No file targets match the literal IncludePath selector(s):*Missing.ps1*'
        Should -Invoke New-AstDocument -ModuleName Nitpick -Times 0 -Exactly -Scope It
    }

    It 'does not apply file-target requirements to in-memory scripts' {
        $Results = @(Start-Nitpicking -Script {} -IncludeRule UseIsNotOperator `
            -IncludePath 'Missing.ps1' -ExcludePath '*' -Output Object)
        $Results | Should -HaveCount 1
        $Results[0].TargetCount | Should -Be 1
    }

    It 'validates known include selectors before applying exclusions' {
        $Results = @(Start-Nitpicking -Script 'param([Parameter(Mandatory=$true)] [string] $Name)' `
            -IncludeRule UseIsNotOperator,AvoidParameterAttributeBool `
            -ExcludeRule '*IsNot*','Missing*' -Output Object -ErrorAction Stop)
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Summary.RuleCount | Should -Be 1
        $Summary.FindingCount | Should -Be 1
        (Get-Nitpick -Name UseIsNotOperator) | Should -BeNullOrEmpty
    }

    It 'terminates when exclusions remove every selected rule' {
        Mock New-AstDocument -ModuleName Nitpick { throw 'Targets must not be parsed.' }

        {
            Start-Nitpicking -Script {} -IncludeRule UseIsNotOperator -ExcludeRule '*' -ErrorAction Continue
        } | Should -Throw 'No eligible Nitpick rules remain after applying rule exclusions and editor-mode filtering.'

        Should -Invoke New-AstDocument -ModuleName Nitpick -Times 0 -Exactly -Scope It
    }

    It 'terminates when no rules are discoverable or registered' {
        Mock Find-Nitpick -ModuleName Nitpick {}
        Mock New-AstDocument -ModuleName Nitpick { throw 'Targets must not be parsed.' }

        {
            Start-Nitpicking -Script {} -ErrorAction Continue
        } | Should -Throw 'No Nitpick rules were discovered or registered.*'

        Should -Invoke New-AstDocument -ModuleName Nitpick -Times 0 -Exactly -Scope It
    }

    It 'validates selectors after discovering explicitly requested rule modules without registration' {
        $Module = New-Module -Name NitpickSelectionRules -ScriptBlock {
            function Test-ModuleRule {
                param($ScriptBlockAst)
            }
            Export-ModuleMember -Function Test-ModuleRule
        }
        Import-Module -ModuleInfo $Module
        Mock Find-Nitpick -ModuleName Nitpick {}
        Mock Find-Nitpick -ModuleName Nitpick {
            Get-Command -Name Test-ModuleRule -Module NitpickSelectionRules
        } -ParameterFilter { $IncludeModule -contains 'NitpickSelectionRules' }

        try {
            $Results = @(Start-Nitpicking -Script {} -RuleModule NitpickSelectionRules `
                -IncludeRule ModuleRule -Output Object -ErrorAction Stop)

            $Results | Should -HaveCount 1
            $Results[0].RuleCount | Should -Be 1
            $Results[0].FindingCount | Should -Be 0
            @(Get-Nitpick) | Should -HaveCount 0
        } finally {
            Remove-Module NitpickSelectionRules -Force
        }
    }

    It 'does not persist automatically discovered rules even after repeated invocations' {
        foreach ($Invocation in 1..2) {
            $Results = @(Start-Nitpicking -Script {} -IncludeRule UseIsNotOperator -Output Object)
            $Results[0].RuleCount | Should -Be 1
            @(Get-Nitpick) | Should -HaveCount 0
        }
    }

    It 'preserves explicit metadata and executes the same discovered callable only once' {
        $Registered = Register-Nitpick -Callable (Get-Command Test-UseIsNotOperator -Module Nitpick) `
            -Category Quality -Source CustomSource -PassThru
        $Results = @(Start-Nitpicking -Script '-not ($Value -is [int])' `
            -IncludeRule UseIsNotOperator -Output Object -ErrorAction Stop)

        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Summary.RuleCount | Should -Be 1
        $Summary.FindingCount | Should -Be 1

        $Remaining = @(Get-Nitpick)
        $Remaining | Should -HaveCount 1
        [object]::ReferenceEquals($Remaining[0], $Registered) | Should -BeTrue
        $Remaining[0].Category | Should -Be Quality
        $Remaining[0].Source | Should -Be CustomSource
    }

    It 'uses explicit editor enablement rather than discovered defaults' {
        Register-Nitpick -Callable (Get-Command Test-UseIsNotOperator -Module Nitpick) -EditorEnabled $false
        {
            Start-Nitpicking -Script {} -IncludeRule UseIsNotOperator -EditorMode
        } | Should -Throw '*No eligible Nitpick rules remain*'
        (Get-Nitpick -Name UseIsNotOperator).EditorEnabled | Should -BeFalse
    }

    It 'rejects a conflicting explicit callable without modifying the registry or reading targets' {
        $Registered = Register-Nitpick `
            -Callable { param ($ScriptBlockAst) } `
            -Name UseIsNotOperator -Source Tests -PassThru

        Mock New-AstDocument -ModuleName Nitpick { throw 'Analysis must not start.' }
        {
            Start-Nitpicking -Script {} -IncludeRule UseIsNotOperator -ErrorAction Continue
        } | Should -Throw "*Different Nitpick callables share the canonical rule name 'UseIsNotOperator'*"
        Should -Invoke New-AstDocument -ModuleName Nitpick -Times 0 -Exactly -Scope It
        [object]::ReferenceEquals((Get-Nitpick -Name UseIsNotOperator), $Registered) | Should -BeTrue
    }

    It 'does not partially register discovered rules after selector failure' {
        {
            Start-Nitpicking -Script {} -IncludeRule UseIsNotOperator,MissingRule
        } | Should -Throw '*No Nitpick rules match*'
        @(Get-Nitpick) | Should -HaveCount 0
    }

    It 'unregisters explicit metadata without disabling discovery' {
        Register-Nitpick -Callable (Get-Command Test-UseIsNotOperator -Module Nitpick) -EditorEnabled $false
        Unregister-Nitpick -Name UseIsNotOperator
        $Results = @(Start-Nitpicking -Script {} -IncludeRule UseIsNotOperator -EditorMode -Output Object)
        $Results[0].RuleCount | Should -Be 1
        @(Get-Nitpick) | Should -HaveCount 0
    }

    It 'reports parser errors for in-memory scripts as error findings' {
        $Results = @(
            Start-Nitpicking `
                -Script 'if (' `
                -Output Object `
                -WarningAction SilentlyContinue `
                -ErrorAction SilentlyContinue
        )
        $ParseFinding = $Results | Where-Object RuleName -eq 'PowerShellParseError'
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $ParseFinding | Should -Not -BeNullOrEmpty
        $ParseFinding.Severity | Should -Be 'Error'
        $ParseFinding.Message | Should -Not -BeNullOrEmpty
        $Summary.ErrorCount | Should -BeGreaterThan 0
    }

    It 'reports parser errors for file-backed scripts as error findings' {
        $Path = Join-Path $TestDrive 'ParseError.ps1'
        [System.IO.File]::WriteAllText($Path, 'if (')

        try {
            $Results = @(
                Start-Nitpicking `
                    -Path $Path `
                    -Output Object `
                    -WarningAction SilentlyContinue `
                    -ErrorAction SilentlyContinue
            )
            $ParseFinding = $Results | Where-Object RuleName -eq 'PowerShellParseError'
            $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

            $ParseFinding | Should -Not -BeNullOrEmpty
            $ParseFinding.Severity | Should -Be 'Error'
            $ParseFinding.Location | Should -Match 'ParseError\.ps1:'
            $Summary.ErrorCount | Should -BeGreaterThan 0
        } finally {
            Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        }
    }

    It 'continues linting remaining files when a target cannot be read' {
        $MissingPath = Join-Path $TestDrive 'Missing.ps1'
        $ValidPath = Join-Path $TestDrive 'Valid.ps1'
        [System.IO.File]::WriteAllText($ValidPath, '$Value = 1')
        $MissingTarget = [pscustomobject]@{ FullName = $MissingPath }
        $ValidTarget = Get-Item -LiteralPath $ValidPath
        Mock Get-ChildItem -ModuleName Nitpick {
            @($MissingTarget, $ValidTarget)
        }
        $Errors = @()

        try {
            $Results = @(
                Start-Nitpicking `
                    -Path $TestDrive `
                    -Output Object `
                    -WarningAction SilentlyContinue `
                    -ErrorAction SilentlyContinue `
                    -ErrorVariable Errors
            )
            $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

            $Summary.TargetCount | Should -Be 2
            $Summary.FailedTargetCount | Should -Be 1
            $Errors | Should -Not -BeNullOrEmpty
        } finally {
            Remove-Item -LiteralPath $ValidPath -Force -ErrorAction SilentlyContinue
        }
    }

    It 'filters paths using wildcard include and exclude patterns' {
        $IncludedPath = Join-Path $TestDrive 'included.ps1'
        $ExcludedPath = Join-Path $TestDrive 'excluded.ps1'
        $RuleViolation = 'param([Parameter(Mandatory=$true)] [string] $Name)'
        Set-Content -Path $IncludedPath -Value $RuleViolation
        Set-Content -Path $ExcludedPath -Value "$RuleViolation`n$RuleViolation"

        $Results = @(
            Start-Nitpicking `
                -Path $TestDrive `
                -IncludePath '*.ps1' `
                -ExcludePath '*excluded.ps1' `
                -IncludeRule AvoidParameterAttributeBool `
                -Output Object
        )

        $Findings = @($Results | Where-Object { $_.GetType().Name -eq 'NitpickFinding' })
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Findings.Count | Should -Be 1
        $Summary.TargetCount | Should -Be 1
        $Summary.RuleCount | Should -Be 1
        $Summary.FindingCount | Should -Be 1
        $Summary.InformationCount | Should -Be 1
    }

    It 'applies rule path scopes only to file-backed targets' {
        $RuleScript = {
            [CmdletBinding(DefaultParameterSetName='ScriptBlockAst')]
            param(
                [Parameter(Mandatory,ParameterSetName='ScriptBlockAst')]
                [System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst,

                [Parameter(ParameterSetName='Details')]
                [switch] $Details
            )

            if ($Details) {
                return [pscustomobject]@{
                    Name = 'ScopedRule'
                    Source = 'Tests'
                    IncludePath = @('*.dsl.ps1')
                    ExcludePath = @('*/excluded/*')
                }
            }

            New-NitpickFinding `
                -RuleName ScopedRule `
                -Message 'Scoped rule ran' `
                -ViolationExtent $ScriptBlockAst.Extent `
                -Severity Information `
                -RuleSuppressionID ScopedRule `
                -ScriptPath $ScriptBlockAst.Extent.File `
                -Explanation 'Verifies scoped dispatch.' `
                -OutputAs NitpickFinding
        }

        $ExcludedDirectory = New-Item -Path (Join-Path $TestDrive 'excluded') -ItemType Directory
        Set-Content -Path (Join-Path $TestDrive 'included.dsl.ps1') -Value '$Included'
        Set-Content -Path (Join-Path $TestDrive 'ordinary.ps1') -Value '$Ordinary'
        Set-Content -Path (Join-Path $ExcludedDirectory 'excluded.dsl.ps1') -Value '$Excluded'
        Register-Nitpick `
            -Callable $RuleScript `
            -Name ScopedRule `
            -Source Tests

        $PathResults = @(
            Start-Nitpicking `
                -Path $TestDrive `
                -IncludeRule ScopedRule `
                -Output Object `
                -NoSummary
        )
        $ScriptResults = @(
            Start-Nitpicking `
                -Script { $Anonymous } `
                -IncludeRule ScopedRule `
                -Output Object `
                -NoSummary
        )

        $PathResults.Count | Should -Be 1
        $PathResults[0].Location | Should -Match 'included\.dsl\.ps1:'
        $ScriptResults.Count | Should -Be 1
        $ScriptResults[0].RuleName | Should -Be 'ScopedRule'
    }

    It 'returns only findings when NoSummary is specified' {
        $Results = @(
            Start-Nitpicking `
                -Script { param([Parameter(Mandatory=$true)] [string] $Name) } `
                -IncludeRule AvoidParameterAttributeBool `
                -Output Object `
                -NoSummary
        )

        $Results.Count | Should -Be 1
        $Results[0].GetType().Name | Should -Be 'NitpickFinding'
    }

    It 'does not invoke editor-disabled rules in editor mode' {
        $Rule = {
            param([System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst)

            throw 'Editor-disabled rule was invoked.'
        }
        Register-Nitpick `
            -Callable $Rule `
            -Name EditorDisabledRule `
            -Source Tests `
            -EditorEnabled:$false

        {
            Start-Nitpicking `
                -Script {} `
                -IncludeRule EditorDisabledRule `
                -EditorMode `
                -Output Object `
                -ErrorAction Continue
        } | Should -Throw 'No eligible Nitpick rules remain after applying rule exclusions and editor-mode filtering.'
    }

    It 'returns finding and summary text by default' {
        $Script = [scriptblock]::Create(
            'param([Parameter(Mandatory=$true)] [string] $Name)'
        )
        $Results = @(
            Start-Nitpicking `
                -Script $Script.Ast `
                -IncludeRule AvoidParameterAttributeBool
        )

        $Results.Count | Should -Be 2
        $Results[0] | Should -BeOfType ([string])
        $Results[0] | Should -Match '^<ScriptBlock>\r?\n  \d+:\d+  information  Avoid assigning Boolean values to Parameter attribute arguments  AvoidParameterAttributeBool$'
        $Results[1] | Should -BeOfType ([string])
        $Results[1] | Should -Match '^1 finding \(0 errors, 0 warnings, 1 information\) across 1 target in [\d,]+ ms$'
    }

    It 'sorts text findings by source position within each target' {
        $Rule = {
            param([System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst)

            $Variables = @($ScriptBlockAst.FindAll({
                param($Node)
                $Node -is [System.Management.Automation.Language.VariableExpressionAst]
            }, $false))
            foreach ($Variable in $Variables | Sort-Object { $_.Extent.StartLineNumber } -Descending) {
                New-NitpickFinding `
                    -RuleName OutOfOrder `
                    -Message "$($Variable.VariablePath.UserPath) finding" `
                    -ViolationExtent $Variable.Extent `
                    -Severity Information `
                    -RuleSuppressionID OutOfOrder `
                    -ScriptPath '<ScriptBlock>' `
                    -Explanation 'Returns findings out of order.' `
                    -OutputAs NitpickFinding
            }
        }
        Register-Nitpick -Callable $Rule -Name OutOfOrder -Source Tests
        $Script = [scriptblock]::Create("`$First`n`$Second")

        $RenderedOutput = Start-Nitpicking `
            -Script $Script.Ast `
            -IncludeRule OutOfOrder `
            -NoSummary

        $Lines = $RenderedOutput -split '\r?\n'
        $Lines.Count | Should -Be 3
        $Lines[1] | Should -Match '^  1:1\s+information\s+First finding\s+OutOfOrder$'
        $Lines[2] | Should -Match '^  2:1\s+information\s+Second finding\s+OutOfOrder$'
    }

    It 'previews corrections and summarizes final findings for in-memory input' {
        $Source = 'param([Parameter(Mandatory=$true)] [string] $Name)'
        $Results = @(
            Start-Nitpicking `
                -Script $Source `
                -IncludeRule AvoidParameterAttributeBool `
                -Fix `
                -Preview `
                -Output Object
        )
        $Preview = $Results | Where-Object {
            $_.PSTypeNames -contains 'Nitpick.CorrectionResult'
        }
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }

        $Preview | Should -Not -BeNullOrEmpty
        $Preview.RenderedText | Should -Be 'param([Parameter(Mandatory)] [string] $Name)'
        $Preview.Diff | Should -Match 'Mandatory=\$true'
        $Preview.Diff | Should -Match 'Mandatory'
        $Preview.Corrections.Accepted | Should -HaveCount 1
        $Preview.WasWritten | Should -BeFalse
        $Summary.FindingCount | Should -Be 0
        $Summary.InformationCount | Should -Be 0
    }

    It 'requires Fix when Preview is specified' {
        {
            Start-Nitpicking `
                -Script '$Value = 1' `
                -Preview `
                -NoSummary
        } | Should -Throw 'The Preview switch requires Fix.'
    }

    It 'exposes rejected corrections and conflicts in object output' {
        $Rule = {
            param([System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst)

            $Extent = $ScriptBlockAst.EndBlock.Statements[0].Extent
            $Corrections = @(
                New-NitpickCorrection `
                    -ViolationExtent $Extent `
                    -ReplacementText '$Value = 456' `
                    -FilePathOrContext '<ScriptBlock>' `
                    -Description 'First replacement.' `
                    -RuleName 'ConflictingRule'

                New-NitpickCorrection `
                    -ViolationExtent $Extent `
                    -ReplacementText '$Value = 789' `
                    -FilePathOrContext '<ScriptBlock>' `
                    -Description 'Second replacement.' `
                    -RuleName 'ConflictingRule'
            )

            New-NitpickFinding `
                -RuleName 'ConflictingRule' `
                -Message 'Conflicting correction test.' `
                -ViolationExtent $Extent `
                -Severity Information `
                -RuleSuppressionID 'ConflictingRule' `
                -Corrections $Corrections `
                -ScriptPath '<ScriptBlock>' `
                -Explanation 'Verifies conflict reporting through Start-Nitpicking.' `
                -OutputAs NitpickFinding
        }
        Register-Nitpick -Callable $Rule -Name ConflictingRule -Source Tests

        $Results = @(
            Start-Nitpicking `
                -Script '$Value = 123' `
                -IncludeRule ConflictingRule `
                -Fix `
                -Preview `
                -Output Object `
                -NoSummary
        )
        $Preview = $Results | Where-Object {
            $_.PSTypeNames -contains 'Nitpick.CorrectionResult'
        }

        $Preview.Corrections.Skipped | Should -HaveCount 2
        $Preview.Corrections.Conflicts | Should -HaveCount 1
        $Preview.RenderedText | Should -Be '$Value = 123'
        $Preview.Diff | Should -Be 'No queued edits.'
    }

    It 'errors for <FindingSeverity> findings at the <ErrorOn> threshold: <ShouldError>' -ForEach $SeverityThresholdCases {
        $RuleName = "Threshold$FindingSeverity"
        $RuleSeverity = $FindingSeverity
        $Rule = {
            param([System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst)

            New-NitpickFinding `
                -RuleName $RuleName `
                -Message 'Threshold test finding' `
                -ViolationExtent $ScriptBlockAst.Extent `
                -Severity $RuleSeverity `
                -RuleSuppressionID $RuleName `
                -ScriptPath '<ScriptBlock>' `
                -Explanation 'Threshold test finding' `
                -OutputAs NitpickFinding
        }.GetNewClosure()

        Register-Nitpick -Callable $Rule -Name $RuleName -Source Tests

        $ThresholdErrors = @()
        $null = Start-Nitpicking `
            -Script {} `
            -IncludeRule $RuleName `
            -ErrorOn $ErrorOn `
            -NoSummary `
            -ErrorAction SilentlyContinue `
            -ErrorVariable ThresholdErrors

        ($ThresholdErrors.Count -gt 0) | Should -Be $ShouldError
    }
}
