BeforeAll {
    Import-Module "$PSScriptRoot/.."
}

Describe 'Get-BcBarcode128' {
    It 'should return a valid barcode string' {
        $Result = Get-BcBarcode128 -Text 'PJJ123C' -Type 'A'
        $Result | Should -Be 'ËPJJ123CVÎ'
    }
}
