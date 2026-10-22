BeforeAll {
    Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
    Import-Module -Name (Join-Path $PSScriptRoot '..\Nitpick.psd1') -Force -ErrorAction Stop

    function New-ContractRulePackage {
        param (
            [Parameter(Mandatory)]
            [string] $Name,

            [Parameter(Mandatory)]
            [string] $Root
        )

        $Directory = New-Item -Path (Join-Path $Root $Name) -ItemType Directory
        $ParentPath = Join-Path $Directory.FullName ($Name + '.psm1')
        $RulesPath = Join-Path $Directory.FullName ($Name + 'Rules.psm1')
        $ManifestPath = Join-Path $Directory.FullName ($Name + '.psd1')

        Set-Content -LiteralPath $ParentPath -Value @'
function Test-ParentRule { param ($ScriptBlockAst) }
Export-ModuleMember -Function Test-ParentRule
'@

        Set-Content -LiteralPath $RulesPath -Value @'
function Get-ContractMessage { 'Declared rule executed.' }
function Test-ContractRule {
    param ($ScriptBlockAst)
    New-NitpickFinding -RuleName ContractRule -Message (Get-ContractMessage) `
        -Severity Information -ViolationExtent $ScriptBlockAst.Extent `
        -RuleSuppressionID ContractRule -ScriptPath '<ScriptBlock>' `
        -Explanation 'Rule package contract.' -OutputAs NitpickFinding
}
function Test-HiddenContractRule { param ($ScriptBlockAst) }
function Test-InvalidContractRule { param ($FilePath) }
Export-ModuleMember -Function Test-ContractRule, Test-InvalidContractRule
'@
        New-ModuleManifest -Path $ManifestPath -RootModule ($Name + '.psm1') `
            -ModuleVersion '1.0.0' -FunctionsToExport Test-ParentRule `
            -PrivateData @{ Linting = @{} }

        Set-ContractManifestLinting -ManifestPath $ManifestPath -Linting @{
            Rules = @('Test-ParentRule')
            RuleModules = @($Name + 'Rules.psm1')
        }

        [pscustomobject] @{
            Name = $Name
            Directory = $Directory.FullName
            ManifestPath = $ManifestPath
            ParentPath = $ParentPath
            RulesPath = $RulesPath
        }
    }

    function Set-ContractManifestLinting {
        # New-ModuleManifest stringifies nested hashtable values passed through
        # -PrivateData (for example 'System.Collections.Hashtable') instead of
        # serializing them as a literal. Patch the resulting placeholder line
        # with real nested hashtable syntax so Import-PowerShellDataFile can
        # read it back as a hashtable.
        param (
            [Parameter(Mandatory)]
            [string] $ManifestPath,

            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [hashtable] $Linting
        )

        $EntryLines = foreach ($Key in $Linting.Keys) {
            $QuotedValues = @($Linting[$Key]) | ForEach-Object { "'$_'" }
            "        $Key = @($($QuotedValues -join ', '))"
        }

        $LintingLiteral = if ($EntryLines.Count -gt 0) {
            "@{`n$($EntryLines -join "`n")`n    }"
        } else {
            '@{}'
        }

        $Content = Get-Content -LiteralPath $ManifestPath -Raw
        $Patched = $Content -replace '(?m)^\s*Linting\s*=.*$', "    Linting = $LintingLiteral"
        Set-Content -LiteralPath $ManifestPath -Value $Patched -NoNewline
    }
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Nitpick rule package contracts' -Tag 'RulePackageContract' {
    BeforeEach {
        InModuleScope Nitpick { (Get-NitpickRegistry).Nitpicks.Clear() }
        $ContractRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -Path $ContractRoot -ItemType Directory
    }

    AfterEach {
        InModuleScope Nitpick -Parameters @{ Root = $ContractRoot } {
            param ($Root)
            (Get-NitpickRegistry).Nitpicks.Clear()
            $ToRemove = @(Get-Module -All | Where-Object { $_.ModuleBase -like "$Root\*" })
            $ToRemove | Remove-Module -Force
        }
    }

    Context 'Existing invariants retained through migration' {
        It 'does not persist rules discovered by repeated invocations' {
            foreach ($Invocation in 1..2) {
                $Results = @(Start-Nitpicking -Script {} -Output Object -ErrorAction Stop)
                $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
                $Summary.RuleCount | Should -BeGreaterThan 0
                @(Get-Nitpick) | Should -HaveCount 0
            }
        }

        It 'preserves explicitly registered metadata for the same discovered callable' {
            $Rule = Register-Nitpick -Callable (Get-Command Test-UseIsNotOperator -Module Nitpick) `
                -Category Quality -Source Personal -PassThru -ErrorAction Stop

            $null = Start-Nitpicking -Script {} -Output Object -ErrorAction Stop

            $Remaining = @(Get-Nitpick)
            $Remaining | Should -HaveCount 1

            [object]::ReferenceEquals($Remaining[0], $Rule) | Should -BeTrue

            $Remaining[0].Category | Should -Be Quality
            $Remaining[0].Source | Should -Be Personal
        }

        It 'terminates failed selection before reading targets or writing fixes' {
            Mock New-AstDocument -ModuleName Nitpick { throw 'Targets must not be read.' }
            Mock Save-AstDocument -ModuleName Nitpick { throw 'Targets must not be written.' }
            {
                Start-Nitpicking -Path $ContractRoot -IncludeRule MissingContractRule `
                    -Fix -Output Object -ErrorAction Continue
            } | Should -Throw '*No Nitpick rules match*'

            Should -Invoke New-AstDocument -ModuleName Nitpick -Times 0 -Exactly -Scope It
            Should -Invoke Save-AstDocument -ModuleName Nitpick -Times 0 -Exactly -Scope It

            @(Get-Nitpick) | Should -HaveCount 0
        }

        It 'retains local diagnostic names and suppression IDs at the external boundary' {
            $Finding = New-NitpickFinding -RuleName ContractRule -RuleSuppressionID ContractSuppression `
                -Message 'Contract finding.' -Severity Information -ViolationExtent {}.Ast.Extent `
                -ScriptPath '<ScriptBlock>' -Explanation 'External identity contract.' `
                -OutputAs NitpickFinding

            $Diagnostic = $Finding.ToDiagnosticRecord()
            $Diagnostic.RuleName | Should -Be ContractRule
            $Diagnostic.RuleSuppressionID | Should -Be ContractSuppression
        }

        It 'retains supporting module scope and private helpers without exporting global commands' {
            $Package = New-ContractRulePackage -Name NitpickContractPackage -Root $ContractRoot
            $Module = New-Module -ReturnResult -ArgumentList $Package.RulesPath -ScriptBlock {
                param ($Path)
                Import-Module -Name $Path -Scope Local -PassThru -ErrorAction Stop
                Export-ModuleMember -Function @() -Alias @()
            }

            $Rule = New-Nitpick -Callable $Module.ExportedCommands['Test-ContractRule']

            $Findings = @($Rule.Invoke({}.Ast))
            $Findings | Should -HaveCount 1
            $Findings[0].Message | Should -Be 'Declared rule executed.'

            @(Get-Command Test-ContractRule -ErrorAction SilentlyContinue) | Should -HaveCount 0
            @(Get-Nitpick) | Should -HaveCount 0
        }

        It 'keeps native coordinated correction previews transactional' {
            $Path = Join-Path $ContractRoot 'Source.ps1'
            $Source = '-not ($Value -is [int])'
            Set-Content -LiteralPath $Path -Value $Source -NoNewline
            $Results = @(Start-Nitpicking -Path $Path -Fix -Preview -Output Object -ErrorAction Stop)

            $Preview = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
            $Preview.Report.EffectiveText | Should -Be ' ($Value -isnot [int])'
            $Preview.Proposal.AcceptedCorrections | Should -HaveCount 2
            $Preview.Application.CommittedCorrections | Should -HaveCount 0
            @($Preview.Proposal.AcceptedCorrections.ChangeSetId | Sort-Object -Unique) | Should -HaveCount 1

            [System.IO.File]::ReadAllText($Path) | Should -Be $Source
        }
    }

    Context 'Phase 1: qualified identity' {
        It 'keeps local Name and descriptive Source separate from the default scriptblock ID' {
            $Rule = New-Nitpick -Name AvoidFoo -Source Personal -Callable { param ($ScriptBlockAst) }
            $Rule.Name | Should -Be AvoidFoo
            $Rule.Namespace | Should -Be Local
            $Rule.Id | Should -Be 'Local/AvoidFoo'
            $Rule.Source | Should -Be Personal
        }

        It 'allows an explicit registration namespace without changing Source' {
            $Rule = New-Nitpick `
                -Namespace ProjectChecks `
                -Name AvoidFoo `
                -Source Personal `
                -Callable { param ($ScriptBlockAst) }

            $Rule.Id | Should -Be 'ProjectChecks/AvoidFoo'
            $Rule.Source | Should -Be Personal
        }

        It 'defaults command identity to its implementing module namespace' {
            $Rule = New-Nitpick -Callable (Get-Command Test-UseIsNotOperator -Module Nitpick)
            $Rule.Name | Should -Be UseIsNotOperator
            $Rule.Namespace | Should -Be Nitpick
            $Rule.Id | Should -Be 'Nitpick/UseIsNotOperator'
        }

        It 'uses the declared namespace when a rule is implemented by a supporting module' {
            $Module = New-Module -Name WPFRules -ScriptBlock {
                function Test-AvoidBlockingUI {
                    param($ScriptBlockAst)
                }
                Export-ModuleMember -Function Test-AvoidBlockingUI
            }

            $Callable = $Module.ExportedCommands['Test-AvoidBlockingUI']

            $Rule = New-Nitpick -Namespace WPF -Callable $Callable
            $Rule.Id | Should -Be 'WPF/AvoidBlockingUI'
            $Rule.Callable.ModuleName | Should -Be WPFRules
        }

        It 'does not accept namespace ownership from callable Details metadata' {
            $Module = New-Module -Name IdentityMetadataRules -ScriptBlock {
                function Test-IdentityMetadata {
                    param(
                        $ScriptBlockAst,
                        [switch] $Details
                    )
                    if ($Details) {
                        return [pscustomobject]@{
                            Namespace = 'Spoofed'
                            Name = 'IdentityMetadata'
                            Source = 'Metadata'
                        }
                    }
                }
                Export-ModuleMember -Function Test-IdentityMetadata
            }

            $Rule = New-Nitpick -Callable $Module.ExportedCommands['Test-IdentityMetadata']
            $Rule.Namespace | Should -Be IdentityMetadataRules
            $Rule.Id | Should -Be 'IdentityMetadataRules/IdentityMetadata'
        }

        It 'rejects invalid identity segments: <Namespace>/<Name>' -ForEach @(
            @{ Namespace = ''; Name = 'AvoidFoo' }
            @{ Namespace = ' '; Name = 'AvoidFoo' }
            @{ Namespace = 'Project/Checks'; Name = 'AvoidFoo' }
            @{ Namespace = 'Project\Checks'; Name = 'AvoidFoo' }
            @{ Namespace = 'Project*'; Name = 'AvoidFoo' }
            @{ Namespace = 'Project?'; Name = 'AvoidFoo' }
            @{ Namespace = 'Project[Checks]'; Name = 'AvoidFoo' }
            @{ Namespace = 'Project'; Name = '' }
            @{ Namespace = 'Project'; Name = ' ' }
            @{ Namespace = 'Project'; Name = 'Avoid/Foo' }
            @{ Namespace = 'Project'; Name = 'Avoid\Foo' }
            @{ Namespace = 'Project'; Name = 'Avoid*' }
        ) {
            {
                New-Nitpick -Namespace $Namespace -Name $Name -Source Personal `
                    -Callable { param ($ScriptBlockAst) } -ErrorAction Stop
            } | Should -Throw
        }
    }

    Context 'Phases 2 and 3: explicit sources (pending resolver and discovery)' {
        It 'reuses an explicitly named loaded instance without reloading its callable' {
            $Package = New-ContractRulePackage -Name NitpickContractPackage -Root $ContractRoot
            $Module = Import-Module -Name $Package.RulesPath -PassThru -ErrorAction Stop
            $Rules = @(Find-Nitpick -Module NitpickContractPackageRules)
            $Rules | Should -HaveCount 1
            [object]::ReferenceEquals($Rules[0].Callable.Module, $Module) | Should -BeTrue
        }

        It 'rejects an ambiguous loaded module name rather than choosing a version' {
            $FirstRoot = New-Item -Path (Join-Path $ContractRoot 'First') -ItemType Directory
            $SecondRoot = New-Item -Path (Join-Path $ContractRoot 'Second') -ItemType Directory
            $First = New-ContractRulePackage -Name NitpickContractPackage -Root $FirstRoot.FullName
            $Second = New-ContractRulePackage -Name NitpickContractPackage -Root $SecondRoot.FullName

            New-ModuleManifest `
                -Path $Second.ManifestPath `
                -RootModule 'NitpickContractPackage.psm1' `
                -ModuleVersion '2.0.0' `
                -FunctionsToExport Test-ParentRule

            $FirstModule = Import-Module -Name $First.ManifestPath -PassThru -ErrorAction Stop
            $SecondModule = Import-Module -Name $Second.ManifestPath -PassThru -ErrorAction Stop

            [object]::ReferenceEquals($FirstModule, $SecondModule) | Should -BeFalse

            { Find-Nitpick -Module NitpickContractPackage -ErrorAction Stop } |
                Should -Throw '*ambiguous*'
        }

        It 'pins a literal path despite a same-named module already being loaded elsewhere' {
            $FirstRoot = New-Item -Path (Join-Path $ContractRoot 'First') -ItemType Directory
            $SecondRoot = New-Item -Path (Join-Path $ContractRoot 'Second') -ItemType Directory
            $First = New-ContractRulePackage -Name NitpickContractPackage -Root $FirstRoot.FullName
            $Second = New-ContractRulePackage -Name NitpickContractPackage -Root $SecondRoot.FullName

            Import-Module -Name $First.RulesPath -ErrorAction Stop

            $Rules = @(Find-Nitpick -Module $Second.RulesPath)
            $Rules | Should -HaveCount 1
            $Rules[0].Callable.Module.Path | Should -Be $Second.RulesPath
        }

        It 'resolves bare manifest filenames relative to the current location' {
            $Package = New-ContractRulePackage -Name NitpickContractPackage -Root $ContractRoot
            Push-Location -LiteralPath $Package.Directory
            try {
                $Rules = @(Find-Nitpick -Module 'NitpickContractPackage.psd1')
                $Rules.Id | Should -Contain 'NitpickContractPackage/ContractRule'
            } finally {
                Pop-Location
            }
        }

        It 'does not execute module code while resolving an invalid static declaration graph' {
            $Package = New-ContractRulePackage -Name NitpickContractPackage -Root $ContractRoot
            $Marker = Join-Path $ContractRoot 'Imported.txt'
            Set-Content -LiteralPath $Package.RulesPath -Value "Set-Content -LiteralPath '$Marker' -Value imported"
            New-ModuleManifest -Path $Package.ManifestPath -RootModule 'NitpickContractPackage.psm1' `
                -ModuleVersion '1.0.0' -PrivateData @{ Linting = @{} }

            Set-ContractManifestLinting -ManifestPath $Package.ManifestPath -Linting @{
                RuleModules = @('NitpickContractPackageRules.psm1', 'Missing.psm1')
            }

            { Find-Nitpick -Module $Package.ManifestPath -ErrorAction Stop } |
                Should -Throw '*Missing.psm1*'

            Test-Path -LiteralPath $Marker | Should -BeFalse
        }
    }

    Context 'Phase 3: manifest package acquisition' {
        It 'returns rule descriptors with top-level ownership and the implementing callable' {
            $Package = New-ContractRulePackage -Name NitpickContractPackage -Root $ContractRoot
            $Rules = @(Find-Nitpick -Module $Package.ManifestPath)
            $Rules | Should -HaveCount 2

            $Rule = $Rules | Where-Object Id -eq 'NitpickContractPackage/ContractRule'
            $Rule.Name | Should -Be ContractRule
            $Rule.Namespace | Should -Be NitpickContractPackage
            $Rule.Callable.Name | Should -Be Test-ContractRule
            $Rule.Callable.Module.Path | Should -Be $Package.RulesPath

            @(Get-Nitpick) | Should -HaveCount 0
        }

        It 'loads supporting rule modules without initializing a rule-modules-only parent' {
            $Package = New-ContractRulePackage -Name NitpickContractPackage -Root $ContractRoot
            Set-Content -LiteralPath $Package.ParentPath -Value 'throw "Parent must not initialize."'
            New-ModuleManifest -Path $Package.ManifestPath -RootModule 'NitpickContractPackage.psm1' `
                -ModuleVersion '1.0.0' -PrivateData @{ Linting = @{} }

            Set-ContractManifestLinting -ManifestPath $Package.ManifestPath -Linting @{
                RuleModules = @('NitpickContractPackageRules.psm1')
            }

            $Rules = @(Find-Nitpick -Module $Package.ManifestPath -ErrorAction Stop)
            $Rules | Should -HaveCount 1
            $Rules[0].Id | Should -Be 'NitpickContractPackage/ContractRule'
            @(Get-Command Test-ContractRule -ErrorAction SilentlyContinue) | Should -HaveCount 0
        }

        It 'treats an empty Linting declaration as empty rather than fallback discovery' {
            $Package = New-ContractRulePackage -Name NitpickContractPackage -Root $ContractRoot
            New-ModuleManifest `
                -Path $Package.ManifestPath `
                -RootModule 'NitpickContractPackage.psm1' `
                -ModuleVersion '1.0.0' `
                -FunctionsToExport Test-ParentRule `
                -PrivateData @{ Linting = @{} }

            Set-ContractManifestLinting -ManifestPath $Package.ManifestPath -Linting @{}
            @(Find-Nitpick -Module $Package.ManifestPath) | Should -HaveCount 0
        }

        It 'discovers only compatible exported commands from an explicit standalone source' {
            $Package = New-ContractRulePackage -Name NitpickContractPackage -Root $ContractRoot
            $Rules = @(Find-Nitpick -Module $Package.RulesPath)
            $Rules | Should -HaveCount 1
            $Rules[0].Id | Should -Be 'NitpickContractPackageRules/ContractRule'
        }

        It 'rejects an explicitly declared invalid rule rather than ignoring it' {
            $Package = New-ContractRulePackage -Name NitpickContractPackage -Root $ContractRoot
            New-ModuleManifest `
                -Path $Package.ManifestPath `
                -RootModule 'NitpickContractPackageRules.psm1' `
                -ModuleVersion '1.0.0' `
                -FunctionsToExport Test-InvalidContractRule `
                -PrivateData @{ Linting = @{} }

            Set-ContractManifestLinting -ManifestPath $Package.ManifestPath -Linting @{
                Rules = @('Test-InvalidContractRule')
            }

            { Find-Nitpick -Module $Package.ManifestPath -ErrorAction Stop } |
                Should -Throw '*Test-InvalidContractRule*'
        }

        It 'rejects cycles in supporting module declarations' {
            $Package = New-ContractRulePackage -Name NitpickContractPackage -Root $ContractRoot
            New-ModuleManifest -Path $Package.ManifestPath -ModuleVersion '1.0.0' `
                -PrivateData @{ Linting = @{} }

            Set-ContractManifestLinting -ManifestPath $Package.ManifestPath -Linting @{
                RuleModules = @('NitpickContractPackage.psd1')
            }

            { Find-Nitpick -Module $Package.ManifestPath -ErrorAction Stop } | Should -Throw '*cycle*'
        }

        It 'reserves Local against module packages' {
            $Package = New-ContractRulePackage -Name Local -Root $ContractRoot
            { Find-Nitpick -Module $Package.ManifestPath -ErrorAction Stop } | Should -Throw '*Local*reserved*'
        }
    }

    Context 'Phase 4: native API cutover' {
        It 'loads packages additively and limits execution with a namespace selector' {
            $Package = New-ContractRulePackage -Name NitpickContractPackage -Root $ContractRoot
            $Baseline = @(Start-Nitpicking -Script {} -Output Object)
            $BaselineSummary = $Baseline | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
            $Results = @(Start-Nitpicking -Script {} -Module $Package.ManifestPath -Output Object)
            $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
            $Summary.RuleCount | Should -Be ($BaselineSummary.RuleCount + 2)
            $Limited = @(Start-Nitpicking -Script {} -Module $Package.ManifestPath `
                -IncludeRule 'NitpickContractPackage/*' -Output Object)

            $LimitedSummary = $Limited | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
            $LimitedSummary.RuleCount | Should -Be 2

            @(Get-Nitpick) | Should -HaveCount 0
        }

        It 'does not discover unrelated loaded modules or undeclared nested rules' {
            $Package = New-ContractRulePackage -Name NitpickContractPackage -Root $ContractRoot
            Import-Module -Name $Package.RulesPath -ErrorAction Stop
            $Rules = @(Find-Nitpick)
            @($Rules | Where-Object Namespace -ne Nitpick) | Should -HaveCount 0

            New-ModuleManifest -Path $Package.ManifestPath -ModuleVersion '1.0.0' `
                -NestedModules 'NitpickContractPackageRules.psm1' -FunctionsToExport @()

            @(Find-Nitpick -Module $Package.ManifestPath) | Should -HaveCount 0
        }

        It 'permits equal local names from different package namespaces' {
            $Alpha = New-ContractRulePackage -Name NitpickContractAlpha -Root $ContractRoot
            $Beta = New-ContractRulePackage -Name NitpickContractBeta -Root $ContractRoot
            $Results = @(
                Start-Nitpicking `
                    -Script {} `
                    -Module $Alpha.ManifestPath,$Beta.ManifestPath `
                    -IncludeRule 'NitpickContractAlpha/ContractRule','NitpickContractBeta/ContractRule' `
                    -Output Object `
                    -ExcludeDefaults
            )

            $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
            $Summary.RuleCount | Should -Be 2
            $Summary.FindingCount | Should -Be 2
        }

        It 'uses case-insensitive qualified registry lookup and exact removal' {
            $Rule = Register-Nitpick -Name AvoidFoo -Source Personal `
                -Callable { param ($ScriptBlockAst) } -PassThru

            [object]::ReferenceEquals((Get-Nitpick -Id 'local/avoidfoo'), $Rule) | Should -BeTrue
            Unregister-Nitpick -Id 'LOCAL/AVOIDFOO'
            @(Get-Nitpick) | Should -HaveCount 0
        }

        It 'preserves registered overrides and deduplicates matching package callables' {
            $Descriptor = Find-Nitpick -IncludeRule 'Nitpick/UseIsNotOperator'
            $Registered = Register-Nitpick -Callable $Descriptor -Category Quality -Source Personal -PassThru
            $Results = @(Start-Nitpicking -Script {} -IncludeRule 'Nitpick/UseIsNotOperator' -Output Object)
            $Results[0].RuleCount | Should -Be 1
            [object]::ReferenceEquals((Get-Nitpick -Id $Descriptor.Id), $Registered) | Should -BeTrue
            $Registered.Category | Should -Be Quality
            $Registered.Source | Should -Be Personal
        }

        It 'rejects conflicting selected IDs before reading targets but allows their exclusion' {
            $Registered = Register-Nitpick -Namespace Nitpick -Name UseIsNotOperator -Source Personal `
                -Callable { param ($ScriptBlockAst) } -PassThru

            Mock New-AstDocument -ModuleName Nitpick { throw 'Targets must not be read.' }
            {
                Start-Nitpicking -Script {} -IncludeRule 'Nitpick/UseIsNotOperator' -ErrorAction Continue
            } | Should -Throw '*Nitpick/UseIsNotOperator*'
            Should -Invoke New-AstDocument -ModuleName Nitpick -Times 0 -Exactly -Scope It

            [object]::ReferenceEquals((Get-Nitpick -Id $Registered.Id), $Registered) | Should -BeTrue

            {
                Start-Nitpicking -Script {} -ExcludeRule 'Nitpick/UseIsNotOperator' -Output Object
            } | Should -Throw 'Targets must not be read.'
            Should -Invoke New-AstDocument -ModuleName Nitpick -Times 1 -Exactly -Scope It
        }

        It 'rejects unqualified native selectors instead of inferring a namespace' {
            { Start-Nitpicking -Script {} -IncludeRule UseIsNotOperator -ErrorAction Continue } |
                Should -Throw '*UseIsNotOperator*'
        }

        It 'validates literal IDs before exclusions while allowing unmatched qualified wildcards' {
            {
                Start-Nitpicking -Script {} -IncludeRule 'Nitpick/UseIsNotOperator','Local/Missing' `
                    -ExcludeRule 'Local/*' -ErrorAction Continue
            } | Should -Throw '*Local/Missing*'
            $Results = @(Start-Nitpicking -Script {} `
                -IncludeRule 'Nitpick/UseIsNotOperator','Local/Missing*' -Output Object)
            $Results[0].RuleCount | Should -Be 1
        }

        It 'replaces source parameters without replacing analyzed-file filters' {
            $Parameters = (Get-Command Start-Nitpicking).Parameters.Keys
            $Parameters | Should -Contain Module
            $Parameters | Should -Not -Contain RulePath
            $Parameters | Should -Not -Contain RuleModule
            $Parameters | Should -Contain IncludePath
            $Parameters | Should -Contain ExcludePath
        }
    }

    Context 'Phase 5: coordinator-owned identity (pending implementation)' -Skip {
        It 'attributes legacy producer names to the executing qualified rule' {
            $Package = New-ContractRulePackage -Name NitpickContractPackage -Root $ContractRoot
            $Results = @(Start-Nitpicking -Script {} -Module $Package.ManifestPath `
                -IncludeRule 'NitpickContractPackage/ContractRule' -Output Object)

            $Findings = @($Results | Where-Object { $_.GetType().Name -eq 'NitpickFinding' })
            $Findings | Should -HaveCount 1
            $Findings[0].RuleId | Should -Be 'NitpickContractPackage/ContractRule'
            $Findings[0].RuleName | Should -Be ContractRule
            $Findings[0].RuleSuppressionID | Should -Be ContractRule

            $Diagnostic = $Findings[0].ToDiagnosticRecord()
            $Diagnostic.RuleName | Should -Be ContractRule
            $Diagnostic.RuleSuppressionID | Should -Be ContractRule
        }

        It 'retains qualified IDs through preview and corrected-source reanalysis' {
            $Results = @(Start-Nitpicking -Script '-not ($Value -is [int])' `
                -IncludeRule 'Nitpick/UseIsNotOperator' -Fix -Preview -Output Object)

            $Preview = $Results | Where-Object { $_.PSTypeNames -contains 'Nitpick.CorrectionResult' }
            $Preview.Report.EffectiveText | Should -Be ' ($Value -isnot [int])'
            $Preview.Report.EffectiveFindings | Should -HaveCount 0
            $Preview.Proposal.AcceptedCorrections | Should -HaveCount 2
            $Preview.Proposal.WasReanalyzed | Should -BeTrue

            $Ids = @($Preview.Proposal.AcceptedCorrections.RuleId | Sort-Object -Unique)
            $Ids | Should -HaveCount 1
            $Ids[0] | Should -Be 'Nitpick/UseIsNotOperator'
        }
    }
}
