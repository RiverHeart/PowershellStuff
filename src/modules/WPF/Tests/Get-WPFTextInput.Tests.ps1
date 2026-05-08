Describe 'Get-WPFTextInput' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should return the default value when dialog is accepted' {
        InModuleScope WPF {
            Mock -CommandName Show-WPFWindow -MockWith {
                param($Window)
                $true
            }

            $Result = Get-WPFTextInput -Prompt 'Enter interval' -Title 'Slideshow' -DefaultValue '3.0'

            $Result | Should -Be -ExpectedValue '3.0'
            Should -Invoke -CommandName Show-WPFWindow -Times 1 -Exactly
        }
    }

    It 'Should return empty string when dialog is cancelled' {
        InModuleScope WPF {
            Mock -CommandName Show-WPFWindow -MockWith {
                param($Window)
                $false
            }

            $Result = Get-WPFTextInput -Prompt 'Enter interval' -Title 'Slideshow' -DefaultValue '3.0'

            $Result | Should -Be -ExpectedValue ''
            Should -Invoke -CommandName Show-WPFWindow -Times 1 -Exactly
        }
    }

    It 'Should throw when numeric bounds are used without -Numeric' {
        {
            Get-WPFTextInput -Prompt 'Enter interval' -Minimum 0.5 -Maximum 5
        } | Should -Throw -ExpectedMessage '*can only be used with -Numeric*'
    }

    It 'Should throw when -Minimum is greater than -Maximum' {
        InModuleScope WPF {
            Mock -CommandName Show-WPFWindow -MockWith {
                param($Window)
                $true
            }

            {
                Get-WPFTextInput -Prompt 'Enter interval' -Numeric -Minimum 10 -Maximum 2
            } | Should -Throw -ExpectedMessage '*-Minimum cannot be greater than -Maximum*'

            Should -Invoke -CommandName Show-WPFWindow -Times 0 -Exactly
        }
    }
}
