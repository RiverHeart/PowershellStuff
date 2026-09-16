Describe 'Find-WPFAstNode' -Tag 'Helpers' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'remains private to the WPF module' {
        Get-Command Find-WPFAstNode -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'treats a Query that emits no values as false' {
        $Result = InModuleScope WPF {
            Find-WPFAstNode -ScriptBlock { Write-Host 'one' } -Type CommandAst -Query { return }
        }

        $Result | Should -BeNullOrEmpty
    }

    It 'rejects a Query that emits multiple values' {
        {
            InModuleScope WPF {
                Find-WPFAstNode -ScriptBlock { Write-Host 'one' } -Type CommandAst -Query {
                    $_
                    $true
                }
            }
        } | Should -Throw '*Find-WPFAstNode query emitted 2 values*CommandAst*'
    }
}
