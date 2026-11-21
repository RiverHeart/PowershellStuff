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

            function Measure-OtherValidNitpick {
                param ($ScriptBlockAst)
            }

            function Test-InvalidNitpick {
                param ($FilePath)
            }

            function Get-UnrelatedCommand {
                param ($ScriptBlockAst)
            }

            Export-ModuleMember -Function @(
                'Test-ValidNitpick'
                'Measure-OtherValidNitpick'
                'Test-InvalidNitpick'
                'Get-UnrelatedCommand'
            )
        }
        Import-Module -ModuleInfo $RuleModule -Force
    }

    AfterEach {
        Remove-Module -Name NitpickDiscoveryRules -Force -ErrorAction SilentlyContinue
    }

    It 'returns only the built-in package by default' {
        $Rules = @(Find-Nitpick)

        $Rules | Should -Not -BeNullOrEmpty
        @($Rules | Where-Object Namespace -ne Nitpick) | Should -HaveCount 0
        $Rules.Id | Should -Contain 'Nitpick/UseIsNotOperator'
    }

    It 'discovers gated rules without executing predicates or checking host capability' {
        $Module = New-Module -Name NitpickGatedDiscoveryRules -ScriptBlock {
            $script:PredicateCalls = 0

            <#
            .SYNOPSIS
                Counts calls from a predicate bound to this module's private scope.
            #>
            function Test-PrivateEligibility {
                $script:PredicateCalls++
                if ($script:FailPredicate) { Write-Error 'private predicate sentinel' }
                $true
            }

            <#
            .SYNOPSIS
                Declares a private-helper predicate and an impossible host prerequisite.
            #>
            function Test-GatedRule {
                [CmdletBinding(DefaultParameterSetName='Rule')]
                [OutputType([hashtable], [string])]
                param(
                    [Parameter(Mandatory,ParameterSetName='Rule')]
                    $ScriptBlockAst,

                    [Parameter(Mandatory,ParameterSetName='Details')]
                    [switch] $Details
                )
                if ($Details) {
                    return @{
                        Applicability = {
                            param([System.Collections.IDictionary] $Context)
                            Test-PrivateEligibility
                        }
                        MinimumAnalysisHostVersion = [version] '999.0'
                    }
                }
                'executed'
            }
            Export-ModuleMember -Function Test-GatedRule
        }

        Import-Module -ModuleInfo $Module -Force

        try {
            $Rules = @(Find-Nitpick -Module NitpickGatedDiscoveryRules -ErrorAction Stop)
            $Rules.Count | Should -Be 1
            $Rules[0].Id | Should -BeExactly 'NitpickGatedDiscoveryRules/GatedRule'
            $Rules[0].MinimumAnalysisHostVersion | Should -Be ([version] '999.0')
            (& $Module { $script:PredicateCalls }) | Should -Be 0

            { $Rules[0].InvokeWithResult({}.Ast, @{}) } |
                Should -Throw -ErrorId '*NitpickUnsupportedAnalysisHost*'
            (& $Module { $script:PredicateCalls }) | Should -Be 1

            $Rules[0].MinimumAnalysisHostVersion = $null
            $Outcome = $Rules[0].InvokeWithResult({}.Ast, @{})
            $Outcome.Status | Should -BeExactly 'Executed'
            $Outcome.Results[0] | Should -BeExactly 'executed'
            (& $Module { $script:PredicateCalls }) | Should -Be 2
            $Registered = $Rules[0] | Register-Nitpick -Category Quality -PassThru
            $Registered.InvokeWithResult({}.Ast, @{}).Status | Should -BeExactly 'Executed'
            (& $Module { $script:PredicateCalls }) | Should -Be 3
            & $Module { $script:FailPredicate = $true }
            { $Registered.InvokeWithResult({}.Ast, @{}) } |
                Should -Throw '*private predicate sentinel*' -ErrorId '*NitpickApplicabilityFailed*'
            (& $Module { $script:PredicateCalls }) | Should -Be 4
        } finally {
            InModuleScope Nitpick {
                (Get-NitpickRegistry).Nitpicks.Remove('NitpickGatedDiscoveryRules/GatedRule')
            }

            Remove-Module NitpickGatedDiscoveryRules -Force -ErrorAction SilentlyContinue
        }
    }

    It 'rejects malformed execution metadata during discovery' {
        $Module = New-Module -Name NitpickMalformedDiscoveryRules -ScriptBlock {
            <#
            .SYNOPSIS
                Returns deliberately malformed host metadata for discovery validation.
            #>
            function Test-MalformedRule {
                [CmdletBinding(DefaultParameterSetName='Rule')]
                [OutputType([hashtable])]
                param(
                    [Parameter(Mandatory,ParameterSetName='Rule')]
                    $ScriptBlockAst,

                    [Parameter(Mandatory,ParameterSetName='Details')]
                    [switch] $Details
                )

                if ($Details) { return @{ MinimumAnalysisHostVersion = '7.0' } }
            }

            Export-ModuleMember -Function Test-MalformedRule
        }

        Import-Module -ModuleInfo $Module -Force

        try {
            { Find-Nitpick -Module NitpickMalformedDiscoveryRules -ErrorAction Stop } |
                Should -Throw '*MinimumAnalysisHostVersion*'
        } finally {
            Remove-Module NitpickMalformedDiscoveryRules -Force -ErrorAction SilentlyContinue
        }
    }

    It 'acquires nothing when IncludeDefaults is explicitly suppressed with no Module' {
        $Rules = @(Find-Nitpick -IncludeDefaults:$false)

        $Rules | Should -HaveCount 0
    }

    It 'does not discover an unrelated loaded module by default' {
        $Rules = @(Find-Nitpick)

        $Rules.Name | Should -Not -Contain 'ValidNitpick'
    }

    It 'acquires an explicitly requested module as a standalone package' {
        $Rules = @(Find-Nitpick -Module NitpickDiscoveryRules)

        $Rules.Count | Should -Be 2
        $Rules.Id | Should -Contain 'NitpickDiscoveryRules/ValidNitpick'
        $Rules.Id | Should -Contain 'NitpickDiscoveryRules/OtherValidNitpick'
        $Rules.Namespace | Should -Contain 'NitpickDiscoveryRules'
    }

    It 'does not include an exported command missing the required parameter' {
        $Rules = @(Find-Nitpick -Module NitpickDiscoveryRules)

        $Rules.Name | Should -Not -Contain 'InvalidNitpick'
    }

    It 'does not include an unrelated exported command' {
        $Rules = @(Find-Nitpick -Module NitpickDiscoveryRules)

        $Rules.Name | Should -Not -Contain 'UnrelatedCommand'
    }

    It 'filters rules by wildcard qualified ID' {
        $Rules = @(Find-Nitpick `
            -Module NitpickDiscoveryRules `
            -IncludeRule 'NitpickDiscoveryRules/*Valid*'
        )

        $Rules.Count | Should -Be 2
    }

    It 'excludes rules by qualified ID' {
        $Rules = @(Find-Nitpick `
            -Module NitpickDiscoveryRules `
            -ExcludeRule 'NitpickDiscoveryRules/*'
        )

        $Rules.Count | Should -Be 0
    }

    It 'allows unmatched include selectors without raising an error' {
        $Errors = @()
        $Rules = @(Find-Nitpick -Module NitpickDiscoveryRules `
            -IncludeRule 'NitpickDiscoveryRules/MissingRule' -ErrorAction Stop -ErrorVariable Errors)

        $Rules | Should -HaveCount 0
        $Errors | Should -HaveCount 0
    }

    It 'replaces the built-in default with a single explicit module entry' {
        $Rules = @(Find-Nitpick -Module NitpickDiscoveryRules)

        @($Rules | Where-Object Namespace -eq Nitpick) | Should -HaveCount 0
        @($Rules | Where-Object Namespace -eq NitpickDiscoveryRules) | Should -HaveCount 2
    }

    It 'accepts multiple module entries additively' {
        $Rules = @(Find-Nitpick -Module Nitpick, NitpickDiscoveryRules)

        @($Rules | Where-Object Namespace -eq Nitpick) | Should -Not -BeNullOrEmpty
        @($Rules | Where-Object Namespace -eq NitpickDiscoveryRules) | Should -HaveCount 2
    }

    It 'acquires the built-in package alongside an explicit module when IncludeDefaults is specified' {
        $Rules = @(Find-Nitpick -Module NitpickDiscoveryRules -IncludeDefaults)

        @($Rules | Where-Object Namespace -eq Nitpick) | Should -Not -BeNullOrEmpty
        @($Rules | Where-Object Namespace -eq NitpickDiscoveryRules) | Should -HaveCount 2
    }

    It 'writes a non-terminating error and continues past an unresolvable module' {
        $Errors = @()
        $Rules = @(
            Find-Nitpick `
            -Module 'NitpickDiscoveryRules', 'MissingModule' `
            -ErrorAction SilentlyContinue `
            -ErrorVariable Errors
        )

        $Rules.Count | Should -Be 2
        $Errors | Should -Not -BeNullOrEmpty
    }
}
