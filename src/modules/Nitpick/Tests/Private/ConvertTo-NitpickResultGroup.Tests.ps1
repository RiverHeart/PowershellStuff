BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertTo-NitpickResultGroup' {
    It 'defaults every property to an empty array when no value is supplied' {
        $Result = InModuleScope Nitpick {
            ConvertTo-NitpickResultGroup -PropertyName 'Accepted', 'Fixed'
        }

        $Result.PSObject.Properties.Name | Should -Be @('Accepted', 'Fixed')
        ($Result.Accepted -is [array]) | Should -BeTrue
        $Result.Accepted.Count | Should -Be 0
        $Result.Fixed.Count | Should -Be 0
    }

    It 'applies only the overrides present in the supplied hashtable' {
        $Result = InModuleScope Nitpick {
            ConvertTo-NitpickResultGroup `
                -PropertyName 'Accepted', 'Fixed', 'Skipped' `
                -Value @{ Fixed = 'one', 'two' }
        }

        $Result.Accepted.Count | Should -Be 0
        $Result.Fixed | Should -Be @('one', 'two')
        $Result.Skipped.Count | Should -Be 0
    }

    It 'does not share array instances between separate calls' {
        $First, $Second = InModuleScope Nitpick {
            ConvertTo-NitpickResultGroup -PropertyName 'Fixed'
            ConvertTo-NitpickResultGroup -PropertyName 'Fixed'
        }

        $First.Fixed += 'fixed'

        $Second.Fixed.Count | Should -Be 0
    }
}
