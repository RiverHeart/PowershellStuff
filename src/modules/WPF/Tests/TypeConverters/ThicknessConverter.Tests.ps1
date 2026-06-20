Describe 'ThicknessConverter' -Tag 'ThicknessConverter' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../WPF.psd1" -Force
    }

    BeforeAll {
        $WarningPreference = 'SilentlyContinue'
    }

    It 'Should convert a single text value to uniform thickness' {
        $Thickness = [System.Windows.Thickness] '0'

        $Thickness.Left | Should -Be -ExpectedValue 0
        $Thickness.Top | Should -Be -ExpectedValue 0
        $Thickness.Right | Should -Be -ExpectedValue 0
        $Thickness.Bottom | Should -Be -ExpectedValue 0
    }

    It 'Should convert a single numeric value to uniform thickness' {
        $Thickness = [System.Windows.Thickness] 2.5

        $Thickness.Left | Should -Be -ExpectedValue 2.5
        $Thickness.Top | Should -Be -ExpectedValue 2.5
        $Thickness.Right | Should -Be -ExpectedValue 2.5
        $Thickness.Bottom | Should -Be -ExpectedValue 2.5
    }

    It 'Should convert comma-separated text to thickness' {
        $Thickness = [System.Windows.Thickness] '5, 10, 15, 20'

        $Thickness.Left | Should -Be -ExpectedValue 5
        $Thickness.Top | Should -Be -ExpectedValue 10
        $Thickness.Right | Should -Be -ExpectedValue 15
        $Thickness.Bottom | Should -Be -ExpectedValue 20
    }

    It 'Should convert a four-value array to thickness' {
        $Thickness = [System.Windows.Thickness] @(1, 2, 3, 4)

        $Thickness.Left | Should -Be -ExpectedValue 1
        $Thickness.Top | Should -Be -ExpectedValue 2
        $Thickness.Right | Should -Be -ExpectedValue 3
        $Thickness.Bottom | Should -Be -ExpectedValue 4
    }

    It 'Should support tuple-style margin assignment in DSL controls' {
        $Id = [guid]::NewGuid().ToString('N')

        $Label = Label "MarginLabel_$Id" {
            $this.Margin = 8, 6, 4, 2
        }

        $Label.Margin.Left | Should -Be -ExpectedValue 8
        $Label.Margin.Top | Should -Be -ExpectedValue 6
        $Label.Margin.Right | Should -Be -ExpectedValue 4
        $Label.Margin.Bottom | Should -Be -ExpectedValue 2
    }

    It 'Should support single-value thickness assignment in styles' {
        $StyleName = [guid]::NewGuid().ToString('N')

        Style $StyleName Border {
            Setter BorderThickness 0
        }

        $Border = Border {
            UseStyle $StyleName
        }

        $Border.BorderThickness.Left | Should -Be -ExpectedValue 0
        $Border.BorderThickness.Top | Should -Be -ExpectedValue 0
        $Border.BorderThickness.Right | Should -Be -ExpectedValue 0
        $Border.BorderThickness.Bottom | Should -Be -ExpectedValue 0
    }

    It 'Should support double thickness assignment in styles' {
        $StyleName = [guid]::NewGuid().ToString('N')

        Style $StyleName Border {
            Setter BorderThickness 1.5
        }

        $Border = Border {
            UseStyle $StyleName
        }

        $Border.BorderThickness.Left | Should -Be -ExpectedValue 1.5
        $Border.BorderThickness.Top | Should -Be -ExpectedValue 1.5
        $Border.BorderThickness.Right | Should -Be -ExpectedValue 1.5
        $Border.BorderThickness.Bottom | Should -Be -ExpectedValue 1.5
    }

    It 'Should throw for invalid thickness values' {
        { [System.Windows.Thickness] '1,2,bad,4' } | Should -Throw
    }
}
