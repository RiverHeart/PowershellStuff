Describe 'WPF completion type registry helpers' -Tag 'WPFCompletionType' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    BeforeEach {
        InModuleScope WPF {
            Unregister-WPFCompletionType -All
        }
    }

    It 'registers and returns completion type mappings' {
        InModuleScope WPF {
            Register-WPFCompletionType -Name FancyControl -Type ([System.Windows.Controls.TextBlock])
        }

        $entry = InModuleScope WPF {
            Get-WPFCompletionType -Name FancyControl
        }

        $entry | Should -Not -Be $null
        $entry.Name | Should -Be 'FancyControl'
        $entry.Type | Should -Be ([System.Windows.Controls.TextBlock])
    }

    It 'requires -Force when replacing an existing mapping' {
        InModuleScope WPF {
            Register-WPFCompletionType -Name FancyControl -Type ([System.Windows.Controls.TextBlock])
        }

        {
            InModuleScope WPF {
                Register-WPFCompletionType -Name FancyControl -Type ([System.Windows.Controls.Button]) -ErrorAction Stop
            }
        } | Should -Throw

        InModuleScope WPF {
            Register-WPFCompletionType -Name FancyControl -Type ([System.Windows.Controls.Button]) -Force
        }

        $entry = InModuleScope WPF {
            Get-WPFCompletionType -Name FancyControl
        }

        $entry.Type | Should -Be ([System.Windows.Controls.Button])
    }

    It 'unregisters mappings by name and via -All' {
        InModuleScope WPF {
            Register-WPFCompletionType -Name One -Type ([System.String])
            Register-WPFCompletionType -Name Two -Type ([System.Int32])
            Unregister-WPFCompletionType -Name One
        }

        $one = InModuleScope WPF {
            Get-WPFCompletionType -Name One
        }
        $two = InModuleScope WPF {
            Get-WPFCompletionType -Name Two
        }

        $one | Should -Be $null
        $two | Should -Not -Be $null

        InModuleScope WPF {
            Unregister-WPFCompletionType -All
        }

        @(InModuleScope WPF { Get-WPFCompletionType }).Count | Should -Be 0
    }
}
