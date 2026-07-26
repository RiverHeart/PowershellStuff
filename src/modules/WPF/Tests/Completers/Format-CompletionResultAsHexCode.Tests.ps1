using namespace System.Collections.ObjectModel
using namespace System.Management.Automation

Describe 'Format-CompletionResultAsHexCode' -Tag 'Format-CompletionResultAsHexCode' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../WPF.psd1" -Force
    }

    BeforeAll {
        function New-TestCommandCompletion {
            param (
                [Parameter(Mandatory)]
                [CompletionResult[]] $CompletionMatches,

                [int] $CurrentMatchIndex = 0,

                [int] $ReplacementIndex = 0,

                [int] $ReplacementLength = 0
            )

            $collection = [Collection[CompletionResult]]::new()

            foreach ($completionMatch in $CompletionMatches) {
                $collection.Add($completionMatch)
            }

            return [CommandCompletion]::new($collection, $CurrentMatchIndex, $ReplacementIndex, $ReplacementLength)
        }
    }

    It 'formats six-digit hex completions and preserves command completion metadata' {
        $commandCompletion = New-TestCommandCompletion -CompletionMatches @(
            [CompletionResult]::new(
                'FFFFFF',
                'FFFFFF',
                [CompletionResultType]::ParameterValue,
                'Named color'
            )
        ) -CurrentMatchIndex 1 -ReplacementIndex 7 -ReplacementLength 6

        $result = InModuleScope WPF -Parameters @{ CommandCompletion = $commandCompletion } {
            param($CommandCompletion)
            Format-CompletionResultAsHexCode -CommandCompletion $CommandCompletion
        }

        $result | Should -BeOfType ([CommandCompletion])
        $result.CurrentMatchIndex | Should -Be 1
        $result.ReplacementIndex | Should -Be 7
        $result.ReplacementLength | Should -Be 6
        $result.CompletionMatches.Count | Should -Be 1
        $result.CompletionMatches[0].CompletionText | Should -Be "'#FFFFFF'"
        $result.CompletionMatches[0].ListItemText | Should -Be 'FFFFFF'
        $result.CompletionMatches[0].ToolTip | Should -Be 'Named color'
    }

    It 'formats matching entries without dropping non-hex completion entries' {
        $commandCompletion = New-TestCommandCompletion -CompletionMatches @(
            [CompletionResult]::new(
                'FFFFFF',
                'FFFFFF',
                [CompletionResultType]::ParameterValue,
                'Hex value'
            ),
            [CompletionResult]::new(
                '#00FF00',
                '#00FF00',
                [CompletionResultType]::ParameterValue,
                'Already formatted'
            ),
            [CompletionResult]::new(
                'Green',
                'Green',
                [CompletionResultType]::ParameterValue,
                'Named color'
            )
        )

        $result = InModuleScope WPF -Parameters @{ CommandCompletion = $commandCompletion } {
            param($CommandCompletion)
            Format-CompletionResultAsHexCode -CommandCompletion $CommandCompletion
        }

        $result.CompletionMatches.Count | Should -Be 3
        $result.CompletionMatches[0].CompletionText | Should -Be "'#FFFFFF'"
        $result.CompletionMatches[1].CompletionText | Should -Be '#00FF00'
        $result.CompletionMatches[2].CompletionText | Should -Be 'Green'
    }

    It 'accepts lowercase hex values without altering the original list item text casing' {
        $commandCompletion = New-TestCommandCompletion -CompletionMatches @(
            [CompletionResult]::new(
                'ff00aa',
                'ff00aa',
                [CompletionResultType]::ParameterValue,
                'Lowercase hex'
            )
        )

        $result = InModuleScope WPF -Parameters @{ CommandCompletion = $commandCompletion } {
            param($CommandCompletion)
            Format-CompletionResultAsHexCode -CommandCompletion $CommandCompletion
        }

        $result.CompletionMatches.Count | Should -Be 1
        $result.CompletionMatches[0].CompletionText | Should -Be "'#ff00aa'"
        $result.CompletionMatches[0].ListItemText | Should -Be 'ff00aa'
    }
}
