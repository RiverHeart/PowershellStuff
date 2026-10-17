BeforeAll {
    $NitpickManifestPath = Join-Path $PSScriptRoot '..\..\..\Nitpick.psd1'
    Import-Module -Name $NitpickManifestPath -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Start-Nitpicking Module' {
    BeforeEach {
        InModuleScope Nitpick {
            (Get-NitpickRegistry).Nitpicks.Clear()
        }
        $ModuleName = 'NitpickPathRules' + [guid]::NewGuid().ToString('N')
        $ModuleDirectory = New-Item -Path (Join-Path $TestDrive $ModuleName) -ItemType Directory
        $ScriptModulePath = Join-Path $ModuleDirectory.FullName ($ModuleName + '.psm1')
        $ManifestPath = Join-Path $ModuleDirectory.FullName ($ModuleName + '.psd1')
        Set-Content -LiteralPath $ScriptModulePath -Value @'
function Get-PrivateMessage { 'Custom rule executed.' }
function Test-PathRule {
    param ($ScriptBlockAst)
    New-NitpickFinding -Message (Get-PrivateMessage) -RuleName PathRule `
        -Severity Information -ViolationExtent $ScriptBlockAst.Extent `
        -RuleSuppressionID PathRule -ScriptPath '<ScriptBlock>' -Explanation 'Test rule.'
}
function Test-HiddenPathRule { param ($ScriptBlockAst) }
function Test-InvalidPathRule { param ($FilePath) }
Export-ModuleMember -Function Test-PathRule, Test-InvalidPathRule
'@
        New-ModuleManifest -Path $ManifestPath -RootModule ($ModuleName + '.psm1') `
            -FunctionsToExport Test-PathRule,Test-InvalidPathRule -ModuleVersion '1.0.0'
    }

    AfterEach {
        InModuleScope Nitpick -Parameters @{
            ModuleNames = @($ModuleName, 'NitpickOtherPathRules', 'NitpickConflictingPathRules')
        } {
            param ($ModuleNames)
            (Get-NitpickRegistry).Nitpicks.Clear()
            Get-Module -All | Where-Object { $_.Name -in $ModuleNames } | Remove-Module -Force
        }
    }

    It 'loads and executes a rule from <Kind> before selector validation' -ForEach @(
        @{ Kind = 'manifest' }
        @{ Kind = 'script module' }
        @{ Kind = 'directory with manifest' }
        @{ Kind = 'directory with script module' }
        @{ Kind = 'relative path' }
    ) {
        $ModulePath = switch ($Kind) {
            'manifest' { $ManifestPath }
            'script module' { $ScriptModulePath }
            'directory with manifest' { $ModuleDirectory.FullName }
            'directory with script module' {
                Remove-Item -LiteralPath $ManifestPath
                $ModuleDirectory.FullName
            }
            'relative path' {
                Push-Location -LiteralPath $TestDrive
                Join-Path (Join-Path '.' $ModuleName) ($ModuleName + '.psd1')
            }
        }
        try {
            $Results = @(Start-Nitpicking -Script '$Value = 1' -Module $ModulePath `
                -IncludeRule "$ModuleName/PathRule" -Output Object -ErrorAction Stop)
        } finally {
            if ($Kind -eq 'relative path') { Pop-Location }
        }

        $Finding = @($Results | Where-Object { $_.GetType().Name -eq 'NitpickFinding' })
        $Finding | Should -HaveCount 1
        $Finding[0].Message | Should -Be 'Custom rule executed.'
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Summary.RuleCount | Should -Be 1
        $Summary.FindingCount | Should -Be 1
        @(Get-Command Test-PathRule -ErrorAction SilentlyContinue) | Should -HaveCount 0
    }

    It 'prefers the directory manifest and respects its export restrictions' {
        New-ModuleManifest -Path $ManifestPath -RootModule ($ModuleName + '.psm1') `
            -FunctionsToExport @() -ModuleVersion '1.0.0'
        {
            Start-Nitpicking -Script {} -Module $ModuleDirectory.FullName -IncludeRule "$ModuleName/PathRule"
        } | Should -Throw "*No Nitpick rules match the IncludeRule selector(s): $ModuleName/PathRule*"
    }

    It 'discovers only exported valid rules and retains additive built-in discovery' {
        $Results = @(Start-Nitpicking -Script {} -Module $ManifestPath -Output Object)
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Summary.RuleCount | Should -Be 3
        @(Get-Nitpick) | Should -HaveCount 0
        @(Get-Nitpick -Id "$ModuleName/HiddenPathRule", "$ModuleName/InvalidPathRule") | Should -HaveCount 0
    }

    It 'supports multiple paths and repeated imports without forcing reloads' {
        $OtherModulePath = Join-Path $TestDrive 'NitpickOtherPathRules.psm1'
        Set-Content -LiteralPath $OtherModulePath -Value @'
function Measure-OtherPathRule { param ($ScriptBlockAst) }
Export-ModuleMember -Function Measure-OtherPathRule
'@
        foreach ($Invocation in 1..2) {
            $Results = @(Start-Nitpicking -Script {} `
                -Module $ManifestPath,$OtherModulePath,$ManifestPath `
                -IncludeRule "$ModuleName/PathRule",'NitpickOtherPathRules/OtherPathRule' -Output Object -ErrorAction Stop)
            $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
            $Summary.RuleCount | Should -Be 2
        }
    }

    It 'does not persist path-acquired rules or make them discoverable by default afterward' {
        $null = Start-Nitpicking -Script {} -Module $ManifestPath -IncludeRule "$ModuleName/PathRule" -Output Object
        @(Get-Nitpick) | Should -HaveCount 0
        @(Find-Nitpick -IncludeRule "$ModuleName/PathRule") | Should -HaveCount 0
        {
            Start-Nitpicking -Script {} -IncludeRule "$ModuleName/PathRule" -Output Object -ErrorAction Stop
        } | Should -Throw "*No Nitpick rules match the IncludeRule selector(s): $ModuleName/PathRule*"
    }

    It 'applies include wildcards and exclusions to path-loaded rules' {
        $Results = @(Start-Nitpicking -Script {} -Module $ManifestPath `
            -IncludeRule '*/*Rule','Nitpick/UseIsNotOperator' -ExcludeRule "$ModuleName/PathRule" -Output Object)
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Summary.RuleCount | Should -Be 1
        @(Get-Nitpick -Id "$ModuleName/PathRule") | Should -HaveCount 0
    }

    It 'does not automatically traverse undeclared nested modules' {
        New-ModuleManifest -Path $ManifestPath -NestedModules ($ModuleName + '.psm1') `
            -FunctionsToExport @() -ModuleVersion '1.0.0'
        {
            Start-Nitpicking -Script {} -Module $ManifestPath `
                -IncludeRule "$ModuleName/PathRule" -ErrorAction Stop
        } | Should -Throw "*No Nitpick rules match the IncludeRule selector(s): $ModuleName/PathRule*"
    }

    It 'validates a module source before reading targets' {
        $MissingPath = Join-Path $TestDrive 'Missing.psm1'
        Mock New-AstDocument -ModuleName Nitpick { throw 'Analysis must not start.' }
        {
            Start-Nitpicking -Script {} -Module $MissingPath `
                -IncludeRule Nitpick/UseIsNotOperator -ErrorAction Continue
        } | Should -Throw
        Should -Invoke New-AstDocument -ModuleName Nitpick -Times 0 -Exactly -Scope It
    }

    It 'runs built-in rules without optional module sources' {
        $Results = @(Start-Nitpicking -Script {} -IncludeRule Nitpick/UseIsNotOperator -Output Object -ErrorAction Stop)
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Summary.RuleCount | Should -Be 1
    }

    It 'propagates module import errors before target analysis even when built-in rules are selected' {
        Set-Content -LiteralPath $ScriptModulePath -Value 'throw "Rule module import failed."'
        Mock New-AstDocument -ModuleName Nitpick { throw 'Analysis must not start.' }
        {
            Start-Nitpicking -Script {} -Module $ScriptModulePath `
                -IncludeRule Nitpick/UseIsNotOperator -ErrorAction Continue
        } | Should -Throw '*Rule module import failed*'
        Should -Invoke New-AstDocument -ModuleName Nitpick -Times 0 -Exactly -Scope It
    }

    It 'does not run a previous package when another path exports the same local rule name' {
        $OtherModulePath = Join-Path $TestDrive 'NitpickOtherPathRules.psm1'
        Set-Content -LiteralPath $OtherModulePath -Value @'
function Test-PathRule { param ($ScriptBlockAst) }
Export-ModuleMember -Function Test-PathRule
'@
        $null = Start-Nitpicking -Script {} -Module $ManifestPath -IncludeRule "$ModuleName/PathRule" -Output Object
        $Results = @(Start-Nitpicking -Script {} -Module $OtherModulePath `
            -IncludeRule 'NitpickOtherPathRules/PathRule' -Output Object -ErrorAction Stop)
        $Results | Should -HaveCount 1
        $Results[0].RuleCount | Should -Be 1
        $Results[0].FindingCount | Should -Be 0
        @(Get-Nitpick) | Should -HaveCount 0
    }

    It 'permits the same local rule name from two different package namespaces in one invocation' {
        $OtherModulePath = Join-Path $TestDrive 'NitpickConflictingPathRules.psm1'
        Set-Content -LiteralPath $OtherModulePath -Value @'
function Test-PathRule { param ($ScriptBlockAst) }
Export-ModuleMember -Function Test-PathRule
'@
        $Results = @(Start-Nitpicking -Script {} -Module $ManifestPath,$OtherModulePath `
            -IncludeRule "$ModuleName/PathRule",'NitpickConflictingPathRules/PathRule' -Output Object -ErrorAction Stop)
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Summary.RuleCount | Should -Be 2
        @(Get-Nitpick) | Should -HaveCount 0
    }
}
