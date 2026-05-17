Describe 'Get-WPFFileInfo' -Tag 'Get-WPFFileInfo' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should include entries that use Categories metadata' {
        InModuleScope WPF {
            $script:WPFFileInfo = @{
                FileInfo = @{
                    PNG = @{ Display = 'PNG'; Categories = 'Image'; Filter = 'PNG (*.png)|*.png' }
                }
            }

            $Results = Get-WPFFileInfo -Category Image

            @($Results.Display) | Should -Contain -ExpectedValue 'PNG'
        }
    }

    It 'Should include entries that use legacy Category metadata' {
        InModuleScope WPF {
            $script:WPFFileInfo = @{
                FileInfo = @{
                    Javascript = @{ Display = 'Javascript'; Category = 'Programming'; Filter = 'Javascript (*.js)|*.js' }
                }
            }

            $Results = Get-WPFFileInfo -Category Programming

            @($Results.Display) | Should -Contain -ExpectedValue 'Javascript'
        }
    }
}
