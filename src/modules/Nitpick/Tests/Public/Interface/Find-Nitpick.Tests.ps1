using namespace System.Management.Automation

BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Find-Nitpick' {
    BeforeEach {
        $RuleModule = New-Module -Name NitpickDiscoveryRules -ScriptBlock {
            function Test-ValidNitpick {
                param ($ScriptBlockAst)
            }

            function Measure-ValidNitpick {
                param ($ScriptBlockAst)
            }

            function Test-InvalidNitpick {
                param ($FilePath)
            }

            function Get-UnrelatedCommand {
                param ($ScriptBlockAst)
            }

            function BareNitpick {
                param ($ScriptBlockAst)
            }

            Export-ModuleMember -Function @(
                'Test-ValidNitpick'
                'Measure-ValidNitpick'
                'Test-InvalidNitpick'
                'Get-UnrelatedCommand'
                'BareNitpick'
            )
        }
        Import-Module -ModuleInfo $RuleModule -Force
    }

    AfterEach {
        Remove-Module -Name NitpickDiscoveryRules -Force -ErrorAction SilentlyContinue
        Remove-Module -Name NitpickDiscoveryParent -Force -ErrorAction SilentlyContinue
        Remove-Module -Name NitpickDiscoveryNestedRules -Force -ErrorAction SilentlyContinue
    }

    It 'returns valid Test and Measure commands from the requested module' {
        [CommandInfo[]] $Rules = Find-Nitpick -IncludeModule NitpickDiscoveryRules

        $Rules.Count | Should -Be 2
        $Rules.Name | Should -Contain 'Test-ValidNitpick'
        $Rules.Name | Should -Contain 'Measure-ValidNitpick'
    }

    It 'filters command names with wildcard patterns' {
        [CommandInfo[]] $Rules = Find-Nitpick -IncludeModule NitpickDiscoveryRules -Name 'Test-*'

        $Rules.Count | Should -Be 1
        $Rules[0].Name | Should -Be 'Test-ValidNitpick'
    }

    It 'filters rules by their noun-derived ID' {
        [CommandInfo[]] $Rules = Find-Nitpick `
            -IncludeModule NitpickDiscoveryRules `
            -IncludeRule ValidNitpick

        $Rules.Count | Should -Be 2
        $Rules.Name | Should -Contain 'Test-ValidNitpick'
        $Rules.Name | Should -Contain 'Measure-ValidNitpick'
    }

    It 'excludes rules by their noun-derived ID' {
        [CommandInfo[]] $Rules = Find-Nitpick `
            -IncludeModule NitpickDiscoveryRules `
            -ExcludeRule ValidNitpick

        $Rules.Count | Should -Be 0
    }

    It 'uses the command name as the rule ID when no noun is available' {
        [CommandInfo[]] $Rules = Find-Nitpick `
            -IncludeModule NitpickDiscoveryRules `
            -IncludeRule BareNitpick

        $Rules.Count | Should -Be 1
        $Rules[0].Name | Should -Be 'BareNitpick'
    }

    It 'matches any of multiple name patterns' {
        [CommandInfo[]] $Rules = Find-Nitpick `
                -IncludeModule NitpickDiscoveryRules `
                -Name 'Measure-*', 'Test-DoesNotExist'

        $Rules.Count | Should -Be 1
        $Rules[0].Name | Should -Be 'Measure-ValidNitpick'
    }

    It 'does not return an invalid command that matches the name filter' {
        [CommandInfo[]] $Rules = Find-Nitpick -IncludeModule NitpickDiscoveryRules -Name 'Test-InvalidNitpick'

        $Rules.Count | Should -Be 0
    }

    It 'does not return commands from modules not requested' {
        [CommandInfo[]] $Rules = Find-Nitpick -IncludeModule Nitpick

        $Rules.Name | Should -Not -Contain 'Test-ValidNitpick'
        $Rules.Name | Should -Not -Contain 'Measure-ValidNitpick'
    }

    It 'returns valid commands exported by nested modules' {
        $ModuleDirectory = New-Item -Path "$TestDrive/NitpickDiscoveryParent" -ItemType Directory
        $NestedModulePath = Join-Path $ModuleDirectory.FullName 'NitpickDiscoveryNestedRules.psm1'
        $ParentModulePath = Join-Path $ModuleDirectory.FullName 'NitpickDiscoveryParent.psd1'

        Set-Content -Path $NestedModulePath -Value @'
function Test-NestedNitpick {
    param ($ScriptBlockAst)
}

function Test-InvalidNestedNitpick {
    param ($FilePath)
}

Export-ModuleMember -Function Test-NestedNitpick, Test-InvalidNestedNitpick
'@
        New-ModuleManifest `
            -Path $ParentModulePath `
            -NestedModules 'NitpickDiscoveryNestedRules.psm1' `
            -FunctionsToExport @() `
            -ModuleVersion '1.0.0'
        Import-Module -Name $ParentModulePath -Force

        [CommandInfo[]] $Rules = Find-Nitpick -IncludeModule NitpickDiscoveryParent

        $Rules.Count | Should -Be 1
        $Rules[0].Name | Should -Be 'Test-NestedNitpick'
        $Rules[0].ModuleName | Should -Be 'NitpickDiscoveryNestedRules'
    }
}
