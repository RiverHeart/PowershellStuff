Describe 'Test-WPFSmokeTestMode' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
        $script:OriginalSmokeValue = [Environment]::GetEnvironmentVariable('WPF_SMOKE_TEST')
    }

    AfterAll {
        [Environment]::SetEnvironmentVariable('WPF_SMOKE_TEST', $script:OriginalSmokeValue)
    }

    It 'Should return false when env var is unset' {
        InModuleScope WPF {
            [Environment]::SetEnvironmentVariable('WPF_SMOKE_TEST', $null)
            Test-WPFSmokeTestMode | Should -BeFalse
        }
    }

    It 'Should return true for enabled values' {
        InModuleScope WPF {
            foreach ($Value in @('1', 'true', 'TRUE', 'yes', 'on')) {
                [Environment]::SetEnvironmentVariable('WPF_SMOKE_TEST', $Value)
                Test-WPFSmokeTestMode | Should -BeTrue
            }
        }
    }

    It 'Should return false for disabled values' {
        InModuleScope WPF {
            foreach ($Value in @('0', 'false', 'no', 'off', 'random')) {
                [Environment]::SetEnvironmentVariable('WPF_SMOKE_TEST', $Value)
                Test-WPFSmokeTestMode | Should -BeFalse
            }
        }
    }
}
