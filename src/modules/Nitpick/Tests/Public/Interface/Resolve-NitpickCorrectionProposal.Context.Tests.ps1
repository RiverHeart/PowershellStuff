using namespace System.Collections
using namespace System.Collections.Generic
using module AstEditor

BeforeAll {
    Import-Module "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Resolve-NitpickCorrectionProposal invocation context' {
    It 'normalizes context before correction selection, even without candidate analysis' {
        $Document = New-AstDocument -InputObject '$Value = 1'

        {
            Resolve-NitpickCorrectionProposal `
                -Document $Document `
                -Finding @() `
                -Context @{ TargetKind = 'File' }
        } | Should -Throw -ErrorId 'NitpickInvalidContext*'
    }

    It 'keeps original file identity and policy on an in-memory candidate document' {
        $Path = Join-Path $TestDrive 'candidate.ps1'
        [IO.File]::WriteAllText($Path, '-not ($Value -is [int])')
        $Document = New-AstDocument -Path $Path
        $FixRule = New-Nitpick -Callable Test-UseIsNotOperator
        $Findings = @($FixRule.Invoke($Document))

        $Observed = [List[object]]::new()
        $Predicate = {
            param([IDictionary] $Context)
            $Observed.Add([pscustomobject]@{
                TargetKind = $Context.TargetKind
                TargetPath = $Context.TargetPath
                MinimumVersion = $Context.Policy.Compatibility.PowerShell.MinimumVersion
            })
            $true
        }.GetNewClosure()

        $ObserverCallable = {
            param([AstDocument] $Candidate, [IDictionary] $Context)
            $Observed.Add([pscustomobject]@{
                IsFileBacked = $Candidate.IsFileBacked
                TargetKind = $Context.TargetKind
                TargetPath = $Context.TargetPath
            })
        }.GetNewClosure()

        $Observer = New-Nitpick `
            -Name CandidateContextObserver `
            -Source Tests `
            -Applicability $Predicate `
            -Callable $ObserverCallable

        $Context = @{
            Policy = @{
                Compatibility = @{
                    PowerShell = @{ MinimumVersion = '5.1' }
                }
            }
        }

        $Proposal = Resolve-NitpickCorrectionProposal `
            -Document $Document `
            -Finding $Findings `
            -Rule @($FixRule, $Observer) `
            -Context $Context

        $Proposal.WasReanalyzed | Should -BeTrue
        $Proposal.Status | Should -Be 'Ready'
        @($Observed) | Should -HaveCount 2
        $Observed[0].TargetKind | Should -BeExactly 'File'
        $Observed[0].TargetPath | Should -BeExactly $Document.Path
        $Observed[0].MinimumVersion | Should -Be ([version] '5.1')
        $Observed[1].IsFileBacked | Should -BeFalse
        $Observed[1].TargetKind | Should -BeExactly 'File'
        $Observed[1].TargetPath | Should -BeExactly $Document.Path
        $Context.Policy.Compatibility.PowerShell.MinimumVersion | Should -BeExactly '5.1'
    }

    It 'rejects direct target identity overrides before candidate selection' {
        $Path = Join-Path $TestDrive 'identity.ps1'
        [IO.File]::WriteAllText($Path, '$Value = 1')
        $Document = New-AstDocument -Path $Path

        {
            Resolve-NitpickCorrectionProposal `
                -Document $Document `
                -Finding @() `
                -Context @{ TargetKind = 'Fragment' }
        } | Should -Throw -ErrorId 'NitpickInvalidContext*'
    }

    It 'rejects coordinator dispatch metadata without the private token' {
        InModuleScope Nitpick {
            $Document = New-AstDocument -InputObject '$Value = 1'
            $Rule = New-Nitpick -Callable Test-UseIsNotOperator
            $Dispatch = @{
                Context = @{}
                Document = $Document
                __NitpickCoordinatorDispatch = @{
                    Token = [object]::new()
                    Target = $Document
                }
            }

            { $Rule.InvokeWithResult($Dispatch) } |
                Should -Throw 'Invalid coordinator-owned rule invocation context.'
        }
    }
}
