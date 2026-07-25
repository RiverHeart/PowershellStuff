BeforeAll {
    Import-Module -Name "$PSScriptRoot/../TabCentral.psd1" -Force
}

Describe 'Assert-Property' {
    It 'does not throw when Test-Property returns true' {
        {
            InModuleScope TabCentral {
                Mock Test-Property { $true }

                Assert-Property -InputObject ([pscustomobject] @{ Name = 'TestHook' }) -Name Name
            }
        } | Should -Not -Throw
    }

    It 'throws when Test-Property returns false' {
        {
            InModuleScope TabCentral {
                Mock Test-Property { $false }

                Assert-Property -InputObject ([pscustomobject] @{ Name = 'TestHook' }) -Name Name
            }
        } | Should -Throw "Property 'Name' failed validation."
    }

    It 'forwards validation parameters to Test-Property' {
        InModuleScope TabCentral {
            Mock Test-Property { $true }
            $InputObject = [pscustomobject] @{ Name = 'TestHook' }

            Assert-Property -InputObject $InputObject -Name Name -Is ([string]) `
                -IsAny ([string], [int]) -Matches '^Test' -Optional -AllowNull -AllowEmpty

            Should -Invoke Test-Property -Times 1 -Exactly -ParameterFilter {
                $InputObject.Name -eq 'TestHook' -and
                $Name -eq 'Name' -and
                $Is -eq [string] -and
                $IsAny.Count -eq 2 -and
                $Matches -eq '^Test' -and
                $Optional -and
                $AllowNull -and
                $AllowEmpty
            }
        }
    }
}
