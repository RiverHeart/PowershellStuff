Describe 'Test-WPFStrictUnexpectedChildMode' -Tag 'Test-WPFStrictUnexpectedChildMode' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    BeforeAll {
        $script:OriginalValue = [Environment]::GetEnvironmentVariable('WPF_STRICT_UNEXPECTED_CHILD')
    }

    AfterAll {
        [Environment]::SetEnvironmentVariable('WPF_STRICT_UNEXPECTED_CHILD', $script:OriginalValue)
    }

    It 'Should return false when env var is unset' {
        InModuleScope WPF {
            [Environment]::SetEnvironmentVariable('WPF_STRICT_UNEXPECTED_CHILD', $null)
            Test-WPFStrictUnexpectedChildMode | Should -BeFalse
        }
    }

    It 'Should return true for enabled values' {
        InModuleScope WPF {
            foreach ($value in @('1', 'true', 'TRUE', 'yes', 'on')) {
                [Environment]::SetEnvironmentVariable('WPF_STRICT_UNEXPECTED_CHILD', $value)
                Test-WPFStrictUnexpectedChildMode | Should -BeTrue
            }
        }
    }

    It 'Should return false for disabled values' {
        InModuleScope WPF {
            foreach ($value in @('0', 'false', 'no', 'off', 'random')) {
                [Environment]::SetEnvironmentVariable('WPF_STRICT_UNEXPECTED_CHILD', $value)
                Test-WPFStrictUnexpectedChildMode | Should -BeFalse
            }
        }
    }
}
