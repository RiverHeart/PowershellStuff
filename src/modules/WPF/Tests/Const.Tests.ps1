Describe 'Const' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should bind Const values for use in a DSL block' {
        $id = [guid]::NewGuid().ToString('N')

        $button = Button "ConstButton_$id" {
            Const ButtonWidth = 56
            $this.Width = $ButtonWidth
        }

        $button.Width | Should -Be -ExpectedValue 56
    }

    It 'Should throw when operator is not equals' {
        { & { Const Bad + 1 } } | Should -Throw -ExceptionType ([System.Data.InvalidExpressionException])
    }

    It 'Should unwrap single-value assignments to scalar values' {
        $id = [guid]::NewGuid().ToString('N')

        $button = Button "ConstScalar_$id" {
            Const ButtonTag = 42
            $this.Tag = $ButtonTag
        }

        $button.Tag.GetType().Name | Should -Be -ExpectedValue 'Int32'
        $button.Tag | Should -Be -ExpectedValue 42
    }

    It 'Should support lowercase const invocation' {
        $id = [guid]::NewGuid().ToString('N')

        $button = Button "LowercaseConst_$id" {
            const ButtonHeight = 48
            $this.Height = $ButtonHeight
        }

        $button.Height | Should -Be -ExpectedValue 48
    }
}
