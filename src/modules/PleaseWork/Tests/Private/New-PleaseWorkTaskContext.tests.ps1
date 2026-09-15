Import-Module "$PSScriptRoot/../../PleaseWork.psd1" -Force

InModuleScope PleaseWork {
    Describe 'New-PleaseWorkTaskContext' {
        It 'creates changeset context for a filtered task' {
            $Changeset = [pscustomobject] @{
                Root = 'C:\repo'
                Files = @('Public/One.ps1')
            }
            $Tasks = @{
                build = [pscustomobject] @{ PathSpecs = @('./Public') }
            }
            Mock Get-GitChangeset { $Changeset }

            $Context = New-PleaseWorkTaskContext `
                -TaskFilePath 'C:\repo\TaskFile.ps1' `
                -TaskFileRoot 'C:\repo' `
                -TaskOrder build `
                -Tasks $Tasks `
                -Config @{ BaseRef = 'origin/main'; HeadRef = 'feature' }

            $Context.TaskFilePath | Should -Be 'C:\repo\TaskFile.ps1'
            $Context.TaskFileRoot | Should -Be 'C:\repo'
            $Context.Changeset | Should -Be $Changeset
            $Context.GitRoot | Should -Be 'C:\repo'
            Should -Invoke Get-GitChangeset -Times 1 -Exactly -ParameterFilter {
                $WorkingDirectory -eq 'C:\repo' -and
                    $BaseRef -eq 'origin/main' -and
                    $HeadRef -eq 'feature'
            }
        }

        It 'uses HEAD when a filtered task does not configure HeadRef' {
            $Tasks = @{
                build = [pscustomobject] @{ PathSpecs = @('./Public') }
            }
            Mock Get-GitChangeset {
                [pscustomobject] @{ Root = 'C:\repo' }
            }

            $null = New-PleaseWorkTaskContext `
                -TaskFilePath 'C:\repo\TaskFile.ps1' `
                -TaskFileRoot 'C:\repo' `
                -TaskOrder build `
                -Tasks $Tasks `
                -Config @{ BaseRef = 'origin/main' }

            Should -Invoke Get-GitChangeset -Times 1 -Exactly -ParameterFilter {
                $HeadRef -eq 'HEAD'
            }
        }

        It 'rejects a filtered task without a base ref' {
            $Tasks = @{
                build = [pscustomobject] @{ PathSpecs = @('./Public') }
            }
            Mock Get-GitChangeset { throw 'Get-GitChangeset should not be called.' }

            { New-PleaseWorkTaskContext `
                -TaskFilePath 'C:\repo\TaskFile.ps1' `
                -TaskFileRoot 'C:\repo' `
                -TaskOrder build `
                -Tasks $Tasks `
                -Config @{} } |
                Should -Throw '*PleaseConfig.BaseRef*'

            Should -Invoke Get-GitChangeset -Times 0 -Exactly
        }
    }
}
