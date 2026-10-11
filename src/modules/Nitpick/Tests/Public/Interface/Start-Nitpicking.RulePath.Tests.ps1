BeforeAll {
    $NitpickManifestPath = Join-Path $PSScriptRoot '..\..\..\Nitpick.psd1'
    Import-Module -Name $NitpickManifestPath -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Start-Nitpicking RulePath' {
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
        $RulePath = switch ($Kind) {
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
            $Results = @(Start-Nitpicking -Script '$Value = 1' -RulePath $RulePath `
                -IncludeRule PathRule -Output Object -ErrorAction Stop)
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
            Start-Nitpicking -Script {} -RulePath $ModuleDirectory.FullName -IncludeRule PathRule
        } | Should -Throw '*No Nitpick rules match the IncludeRule selector(s): PathRule*'
    }

    It 'discovers only exported valid rules and retains default built-in discovery' {
        $Results = @(Start-Nitpicking -Script {} -RulePath $ManifestPath -Output Object)
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Summary.RuleCount | Should -Be 3
        @(Get-Nitpick) | Should -HaveCount 0
        @(Get-Nitpick -IncludeRule HiddenPathRule,InvalidPathRule) | Should -HaveCount 0
    }

    It 'supports multiple paths and repeated imports without forcing reloads' {
        $OtherModulePath = Join-Path $TestDrive 'NitpickOtherPathRules.psm1'
        Set-Content -LiteralPath $OtherModulePath -Value @'
function Measure-OtherPathRule { param ($ScriptBlockAst) }
Export-ModuleMember -Function Measure-OtherPathRule
'@
        foreach ($Invocation in 1..2) {
            $Results = @(Start-Nitpicking -Script {} `
                -RulePath $ManifestPath,$OtherModulePath,$ManifestPath `
                -IncludeRule PathRule,OtherPathRule -Output Object -ErrorAction Stop)
            $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
            $Summary.RuleCount | Should -Be 2
        }
    }

    It 'does not rediscover earlier path imports or persist their rules' {
        $null = Start-Nitpicking -Script {} -RulePath $ManifestPath -IncludeRule PathRule -Output Object
        @(Get-Nitpick) | Should -HaveCount 0
        @(Find-Nitpick -IncludeRule PathRule) | Should -HaveCount 0
        {
            Start-Nitpicking -Script {} -IncludeRule PathRule -Output Object -ErrorAction Stop
        } | Should -Throw '*No Nitpick rules match the IncludeRule selector(s): PathRule*'
    }

    It 'applies include wildcards and exclusions to path-loaded rules' {
        $Results = @(Start-Nitpicking -Script {} -RulePath $ManifestPath `
            -IncludeRule '*Rule',UseIsNotOperator -ExcludeRule PathRule -Output Object)
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Summary.RuleCount | Should -Be 1
        @(Get-Nitpick -IncludeRule PathRule) | Should -HaveCount 0
    }

    It 'discovers rules in nested modules' {
        New-ModuleManifest -Path $ManifestPath -NestedModules ($ModuleName + '.psm1') `
            -FunctionsToExport @() -ModuleVersion '1.0.0'
        $Results = @(Start-Nitpicking -Script {} -RulePath $ManifestPath `
            -IncludeRule PathRule -Output Object -ErrorAction Stop)
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Summary.RuleCount | Should -Be 1
    }

    It 'validates all paths before importing or reading targets: <Kind>' -ForEach @(
        @{ Kind = 'missing' }
        @{ Kind = 'loose script' }
        @{ Kind = 'wildcard' }
        @{ Kind = 'non-filesystem provider' }
        @{ Kind = 'empty' }
        @{ Kind = 'whitespace' }
    ) {
        $InvalidPath = switch ($Kind) {
            'missing' { Join-Path $TestDrive 'Missing.psm1' }
            'loose script' {
                $LooseScript = Join-Path $TestDrive 'Loose.ps1'
                Set-Content -LiteralPath $LooseScript -Value 'throw "Must not execute."'
                $LooseScript
            }
            'wildcard' { Join-Path $ModuleDirectory.FullName '*.psm1' }
            'non-filesystem provider' { 'Env:\PATH' }
            'empty' { '' }
            'whitespace' { ' ' }
        }
        Mock Import-Module -ModuleName Nitpick { throw 'Imports must not start.' }
        Mock New-AstDocument -ModuleName Nitpick { throw 'Analysis must not start.' }
        {
            Start-Nitpicking -Script {} -RulePath $ManifestPath,$InvalidPath `
                -IncludeRule UseIsNotOperator -ErrorAction Continue
        } | Should -Throw
        Should -Invoke Import-Module -ModuleName Nitpick -Times 0 -Exactly -Scope It
        Should -Invoke New-AstDocument -ModuleName Nitpick -Times 0 -Exactly -Scope It
    }

    It 'validates later paths before executing an earlier module' {
        Set-Content -LiteralPath $ScriptModulePath -Value 'throw "Imports must not start."'
        $MissingPath = Join-Path $TestDrive 'Missing.psm1'
        {
            Start-Nitpicking -Script {} -RulePath $ScriptModulePath,$MissingPath `
                -IncludeRule UseIsNotOperator -ErrorAction Continue
        } | Should -Throw '*Missing.psm1*'
    }

    It 'runs built-in rules without optional rule paths' {
        $Results = @(Start-Nitpicking -Script {} -IncludeRule UseIsNotOperator -Output Object -ErrorAction Stop)
        $Summary = $Results | Where-Object { $_.GetType().Name -eq 'NitpickSummary' }
        $Summary.RuleCount | Should -Be 1
    }

    It 'passes directories to Import-Module and propagates module resolution errors' {
        {
            Start-Nitpicking -Script {} -RulePath $TestDrive `
                -IncludeRule UseIsNotOperator -ErrorAction Continue
        } | Should -Throw "*$TestDrive*no valid module file was found*"
    }

    It 'propagates import errors before target analysis even when built-in rules are selected' {
        Set-Content -LiteralPath $ScriptModulePath -Value 'throw "Rule module import failed."'
        Mock New-AstDocument -ModuleName Nitpick { throw 'Analysis must not start.' }
        {
            Start-Nitpicking -Script {} -RulePath $ScriptModulePath `
                -IncludeRule UseIsNotOperator -ErrorAction Continue
        } | Should -Throw '*Rule module import failed*'
        Should -Invoke New-AstDocument -ModuleName Nitpick -Times 0 -Exactly -Scope It
    }

    It 'rejects a settings data file rather than silently ignoring it' {
        Set-Content -LiteralPath $ManifestPath -Value "@{ IncludeRules = @('PathRule') }"
        {
            Start-Nitpicking -Script {} -RulePath $ManifestPath -IncludeRule UseIsNotOperator
        } | Should -Throw
        @(Get-Nitpick) | Should -HaveCount 0
    }

    It 'does not run a previous package when another path exports the same rule name' {
        $OtherModulePath = Join-Path $TestDrive 'NitpickOtherPathRules.psm1'
        Set-Content -LiteralPath $OtherModulePath -Value @'
function Test-PathRule { param ($ScriptBlockAst) }
Export-ModuleMember -Function Test-PathRule
'@
        $null = Start-Nitpicking -Script {} -RulePath $ManifestPath -IncludeRule PathRule -Output Object
        $Results = @(Start-Nitpicking -Script {} -RulePath $OtherModulePath `
            -IncludeRule PathRule -Output Object -ErrorAction Stop)
        $Results | Should -HaveCount 1
        $Results[0].RuleCount | Should -Be 1
        $Results[0].FindingCount | Should -Be 0
        @(Get-Nitpick) | Should -HaveCount 0
    }

    It 'retains registration errors for conflicting canonical names' {
        $OtherModulePath = Join-Path $TestDrive 'NitpickConflictingPathRules.psm1'
        Set-Content -LiteralPath $OtherModulePath -Value @'
function Test-PathRule { param ($ScriptBlockAst) }
Export-ModuleMember -Function Test-PathRule
'@
        {
            Start-Nitpicking -Script {} -RulePath $ManifestPath,$OtherModulePath `
                -IncludeRule PathRule -ErrorAction Continue
        } | Should -Throw "*Different Nitpick callables share the canonical rule name 'PathRule'*"
        @(Get-Nitpick) | Should -HaveCount 0
    }
}
