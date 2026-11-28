using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\..\..\..\Nitpick.psd1') -Force -ErrorAction Stop

    <#
    .SYNOPSIS
        Parses a fixture and invokes the stream suppression rule.

    .PARAMETER Source
        PowerShell source to parse.

    .PARAMETER Recurse
        Whether to inspect nested scriptblocks.
    #>
    function Invoke-ActionPreferenceRule {
        param(
            [string] $Source,
            [bool] $Recurse = $false
        )

        $Tokens = $null
        $ParseErrors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $ParseErrors)
        $ParseErrors | Should -BeNullOrEmpty

        Test-UseActionPreferenceForStreamSuppression -ScriptBlockAst $Ast -Context @{
            RuleBehavior = @{
                SearchNestedScriptBlocks = $Recurse
            }
        }
    }
}

Describe 'Test-UseActionPreferenceForStreamSuppression' {
    It 'reports discarded <Stream> output from <CommandName>' -ForEach @(
        @{
            Stream = 'warning'
            CommandName = 'Write-Warning'
            Source = 'Write-Warning ''message'' 3>$null'
            Action = 'WarningAction'
            Extent = '3>$null'
        }
        @{
            Stream = 'error'
            CommandName = 'Write-Error'
            Source = 'Write-Error ''message'' 2>$null'
            Action = 'ErrorAction'
            Extent = '2>$null'
        }
        @{
            Stream = 'error'
            CommandName = 'Get-Item'
            Source = 'Get-Item missing 2>$null'
            Action = 'ErrorAction'
            Extent = '2>$null'
        }
    ) {
        $Findings = @(Invoke-ActionPreferenceRule -Source $Source)

        $Findings | Should -HaveCount 1
        $Findings[0].RuleId | Should -Be 'Nitpick/UseActionPreferenceForStreamSuppression'
        $Findings[0].Severity | Should -Be 'Information'
        $Findings[0].ViolationExtent.Text | Should -BeExactly $Extent
        $Findings[0].Message | Should -BeLike "*-$Action SilentlyContinue*"
        $Findings[0].Corrections | Should -BeNullOrEmpty
    }

    It 'mentions mocking the writer in tests' {
        $WarningFinding = @(Invoke-ActionPreferenceRule -Source 'Write-Warning ''message'' 3>$null')
        $ErrorFinding = @(Invoke-ActionPreferenceRule -Source 'Write-Error ''message'' 2>$null')

        $WarningFinding[0].Message | Should -Match 'mock Write-Warning'
        $ErrorFinding[0].Message | Should -Match 'mock Write-Error'
    }

    It 'does not report <Label>' -ForEach @(
        @{ Label = 'normal output redirection'; Source = 'Get-Item . 1>$null' }
        @{ Label = 'warning capture'; Source = 'Write-Warning ''message'' 3>$File' }
        @{ Label = 'combined error redirection'; Source = 'Get-Item missing *>$null' }
        @{ Label = 'error-to-warning merge'; Source = 'Get-Item missing 2>&1' }
        @{ Label = 'native command stderr'; Source = 'git status 2>$null' }
        @{ Label = 'invoked native command stderr'; Source = '& git status 2>$null' }
        @{ Label = 'unknown command stderr'; Source = 'Invoke-UnresolvedThing 2>$null' }
    ) {
        @(Invoke-ActionPreferenceRule -Source $Source) | Should -BeNullOrEmpty
    }

    It 'respects nested scriptblock traversal and reports each redirection' {
        $Nested = 'function Invoke-Example { Write-Warning ''nested'' 3>$null }'
        @(Invoke-ActionPreferenceRule -Source $Nested) | Should -BeNullOrEmpty
        @(Invoke-ActionPreferenceRule -Source $Nested -Recurse $true) | Should -HaveCount 1

        $Source = @'
Write-Warning 'one' 3>$null
Write-Error 'two' 2>$null
'@
        @(Invoke-ActionPreferenceRule -Source $Source) | Should -HaveCount 2
    }

    It 'supports metadata, discovery and coordinated identity' {
        $Details = Test-UseActionPreferenceForStreamSuppression -Details

        $Details.Name | Should -Be 'UseActionPreferenceForStreamSuppression'
        $Details.Category | Should -Be 'Quality'
        $Details.Severity | Should -Be 'Information'
        @(Find-Nitpick -IncludeRule Nitpick/UseActionPreferenceForStreamSuppression) |
            Should -HaveCount 1

        $Findings = @(Start-Nitpicking -Script 'Write-Warning ''message'' 3>$null' `
            -IncludeRule Nitpick/UseActionPreferenceForStreamSuppression `
            -Output Object `
            -NoSummary
        )
        $Findings | Should -HaveCount 1
        $Findings[0].RuleId | Should -Be 'Nitpick/UseActionPreferenceForStreamSuppression'
    }

    It 'supports exact qualified suppression' {
        # nitpick disable-next-line Nitpick/AvoidLongLines
        $Source = 'Write-Warning ''intentional'' 3>$null # nitpick disable-line Nitpick/UseActionPreferenceForStreamSuppression -- Deliberate stream redirection.'

        @(Start-Nitpicking -Script $Source `
            -IncludeRule Nitpick/UseActionPreferenceForStreamSuppression `
            -Output Object `
            -NoSummary
        ) | Should -HaveCount 0
    }

    It 'offers no automatic correction because intent determines the replacement' {
        $Source = 'Write-Warning ''message'' 3>$null'
        $Findings = Invoke-ActionPreferenceRule -Source $Source
        $Rule = Find-Nitpick -IncludeRule Nitpick/UseActionPreferenceForStreamSuppression

        $Proposal = Resolve-NitpickCorrectionProposal `
            -Script $Source `
            -Finding $Findings `
            -Rule $Rule

        $Proposal.CandidateText | Should -BeExactly $Source
        $Proposal.AcceptedCorrections | Should -BeNullOrEmpty
    }
}
