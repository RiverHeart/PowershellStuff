Import-Module "$PSScriptRoot/../../PleaseWork.psd1" -Force

InModuleScope PleaseWork {
    Describe 'Format-PleaseWorkTaskHelp' {
        It 'aligns task names and normalizes description whitespace' {
            $TaskInfo = @(
                [pscustomobject] @{
                    Name = 'build'
                    Description = "Builds`n  the project."
                }
                [pscustomobject] @{
                    Name = 'test'
                    Description = $null
                }
            )

            $Output = @($TaskInfo | Format-PleaseWorkTaskHelp)

            $Output | Should -Be @(
                'Available tasks:'
                '  build  Builds the project.'
                '  test'
            )
        }
    }
}
