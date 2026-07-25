BeforeAll {
    Import-Module -Name "$PSScriptRoot/../TabCentral.psd1" -Force
}

Describe 'Assert-Property' {
    It 'accepts a property that satisfies all requested constraints' {
        {
            InModuleScope TabCentral {
                Assert-Property -InputObject ([pscustomobject] @{ Name = 'TestHook' }) `
                    -Name Name -Is ([string]) -Matches '^Test'
            }
        } | Should -Not -Throw
    }

    It 'returns true when an optional property is absent' {
        $Result = InModuleScope TabCentral {
            Assert-Property -InputObject ([pscustomobject] @{}) -Name Name -Optional
        }

        $Result | Should -BeTrue
    }

    It 'writes an error and returns false when a required property is absent' {
        $Errors = @()
        $Result = InModuleScope TabCentral {
            Assert-Property -InputObject ([pscustomobject] @{}) -Name Name -ErrorAction SilentlyContinue -ErrorVariable Errors
            [pscustomobject] @{
                Errors = $Errors
            }
        }

        $Result.Errors.Count | Should -Be 1
        $Result.Errors[0].CategoryInfo.Category | Should -Be 'ObjectNotFound'
    }

    It 'rejects a property with the wrong required type' {
        {
            InModuleScope TabCentral {
                Assert-Property -InputObject ([pscustomobject] @{ Value = 42 }) -Name Value -Is ([string])
            }
        } | Should -Throw "Property 'Value' must be of type 'string'."
    }

    It 'accepts a property matching one of multiple allowed types' {
        {
            InModuleScope TabCentral {
                Assert-Property -InputObject ([pscustomobject] @{ Value = 42 }) `
                    -Name Value -IsAny ([string], [int])
            }
        } | Should -Not -Throw
    }

    It 'rejects a property that matches none of the allowed types' {
        {
            InModuleScope TabCentral {
                Assert-Property -InputObject ([pscustomobject] @{ Value = 42 }) `
                    -Name Value -IsAny ([string], [scriptblock])
            }
        } | Should -Throw "Property 'Value' must be one of the types:*"
    }

    It 'rejects null and empty values by default' {
        {
            InModuleScope TabCentral {
                Assert-Property -InputObject ([pscustomobject] @{ Value = $null }) -Name Value
            }
        } | Should -Throw "Property 'Value' cannot be null."

        {
            InModuleScope TabCentral {
                Assert-Property -InputObject ([pscustomobject] @{ Value = ' ' }) -Name Value
            }
        } | Should -Throw "Property 'Value' cannot be null or empty."
    }

    It 'accepts null and empty values when explicitly allowed' {
        {
            InModuleScope TabCentral {
                Assert-Property -InputObject ([pscustomobject] @{ Value = $null }) `
                    -Name Value -AllowNull -AllowEmpty
                Assert-Property -InputObject ([pscustomobject] @{ Value = '' }) `
                    -Name Value -AllowEmpty
            }
        } | Should -Not -Throw
    }

    It 'rejects a property that does not match the required pattern' {
        {
            InModuleScope TabCentral {
                Assert-Property -InputObject ([pscustomobject] @{ Name = 'OtherHook' }) `
                    -Name Name -Matches '^Test'
            }
        } | Should -Throw "Property 'Name' does not match the pattern '^Test'."
    }
}
