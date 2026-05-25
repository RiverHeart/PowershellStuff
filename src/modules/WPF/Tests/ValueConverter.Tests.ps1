Describe 'ValueConverter' -Tag 'ValueConverter' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should create an IValueConverter from a scriptblock with parameters' {
        $Converter = New-WPFValueConverter {
            param($Value)
            [math]::Round($Value / 1MB, 2)
        }

        $Result = $Converter.Convert(10485760, [object], $null, [System.Globalization.CultureInfo]::InvariantCulture)

        $Converter | Should -BeOfType [System.Windows.Data.IValueConverter]
        $Result | Should -Be 10
    }

    It 'Should support paramless scriptblocks via $_' {
        $Converter = New-WPFValueConverter {
            [math]::Round($_ / 1MB, 2)
        }

        $Result = $Converter.Convert(15728640, [object], $null, [System.Globalization.CultureInfo]::InvariantCulture)

        $Result | Should -Be 15
    }

    It 'Should return Binding.DoNothing when ConvertBack is omitted' {
        $Converter = New-WPFValueConverter {
            param($Value)
            $Value
        }

        $Result = $Converter.ConvertBack('ignored', [object], $null, [System.Globalization.CultureInfo]::InvariantCulture)

        $Result | Should -Be ([System.Windows.Data.Binding]::DoNothing)
    }

    It 'Should use the ConvertBack scriptblock when supplied' {
        $Converter = New-WPFValueConverter {
            param($Value)
            [math]::Round($Value / 1MB, 2)
        } {
            param($Value)
            [int64] ($Value * 1MB)
        }

        $Result = $Converter.ConvertBack(10, [object], $null, [System.Globalization.CultureInfo]::InvariantCulture)

        $Result | Should -Be 10485760
    }
}