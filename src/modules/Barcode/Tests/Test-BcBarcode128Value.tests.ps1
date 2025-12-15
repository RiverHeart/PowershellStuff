BeforeAll {
    Import-Module "$PSScriptRoot/.."
}

Describe 'Test-BcBarcode128Value' {
    It 'should return true for valid characters' {
        Test-BcBarcode128Value 'P' -Type 'A' | Should -BeTrue
    }

    It 'should return false for invalid characters' {
        Test-BcBarcode128Value 'p' -Type 'A' | Should -BeFalse
    }
}
