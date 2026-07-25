BeforeAll {
    Import-Module -Name "$PSScriptRoot/../TabCentral.psd1" -Force
}

Describe 'Test-Property' {
    It 'returns true when a property satisfies all requested constraints' {
        $Result = InModuleScope TabCentral {
            Test-Property -InputObject ([pscustomobject] @{ Name = 'TestHook' }) `
                -Name Name -Is ([string]) -IsAny ([string], [int]) -Matches '^Test'
        }

        $Result | Should -BeTrue
    }

    It 'returns false when a required property is absent' {
        $Result = InModuleScope TabCentral {
            Test-Property -InputObject ([pscustomobject] @{}) -Name Name
        }

        $Result | Should -BeFalse
    }

    It 'returns true when an optional property is absent' {
        $Result = InModuleScope TabCentral {
            Test-Property -InputObject ([pscustomobject] @{}) -Name Name -Optional
        }

        $Result | Should -BeTrue
    }

    It 'validates the required property type' {
        $Result = InModuleScope TabCentral {
            Test-Property -InputObject ([pscustomobject] @{ Value = 42 }) -Name Value -Is ([string])
        }

        $Result | Should -BeFalse
    }

    It 'accepts a property matching any allowed type' {
        $Result = InModuleScope TabCentral {
            Test-Property -InputObject ([pscustomobject] @{ Value = 42 }) `
                -Name Value -IsAny ([string], [int])
        }

        $Result | Should -BeTrue
    }

    It 'rejects a property matching none of the allowed types' {
        $Result = InModuleScope TabCentral {
            Test-Property -InputObject ([pscustomobject] @{ Value = 42 }) `
                -Name Value -IsAny ([string], [scriptblock])
        }

        $Result | Should -BeFalse
    }

    It 'validates null and empty values independently' {
        $Result = InModuleScope TabCentral {
            [pscustomobject] @{
                NullRejected = Test-Property -InputObject ([pscustomobject] @{ Value = $null }) -Name Value
                NullAllowed = Test-Property -InputObject ([pscustomobject] @{ Value = $null }) -Name Value -AllowNull
                EmptyRejected = Test-Property -InputObject ([pscustomobject] @{ Value = ' ' }) -Name Value
                EmptyAllowed = Test-Property -InputObject ([pscustomobject] @{ Value = '' }) -Name Value -AllowEmpty
            }
        }

        $Result.NullRejected | Should -BeFalse
        $Result.NullAllowed | Should -BeTrue
        $Result.EmptyRejected | Should -BeFalse
        $Result.EmptyAllowed | Should -BeTrue
    }

    It 'validates the property against a regular expression' {
        $Result = InModuleScope TabCentral {
            Test-Property -InputObject ([pscustomobject] @{ Name = 'OtherHook' }) `
                -Name Name -Matches '^Test'
        }

        $Result | Should -BeFalse
    }
}
