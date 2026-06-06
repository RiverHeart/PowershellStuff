Describe 'Set-Var' -Tag 'Set-Var' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Converts typed constants with custom WPF type converters' {
        $module = Get-Module -Name WPF
        $constantName = "ConstThickness_$([guid]::NewGuid().ToString('N'))"

        $thickness = & $module {
            param($Name)

            Const [System.Windows.Thickness] $Name = 4, 3, 4, 3
            Get-Variable -Name $Name -ValueOnly
        } $constantName

        $thickness | Should -BeOfType ([System.Windows.Thickness])
        $thickness.Left | Should -Be 4
        $thickness.Top | Should -Be 3
        $thickness.Right | Should -Be 4
        $thickness.Bottom | Should -Be 3
    }

    It 'Converts scalar typed constants with standard conversion rules' {
        $module = Get-Module -Name WPF
        $constantName = "ConstInt_$([guid]::NewGuid().ToString('N'))"

        $value = & $module {
            param($Name)

            Const [int] $Name = '5'
            Get-Variable -Name $Name -ValueOnly
        } $constantName

        $value | Should -Be 5
        $value.GetType() | Should -Be ([int])
    }

    It 'Creates untyped constants without conversion' {
        $module = Get-Module -Name WPF
        $constantName = "ConstUntyped_$([guid]::NewGuid().ToString('N'))"

        $value = & $module {
            param($Name)

            Const $Name = '5'
            Get-Variable -Name $Name -ValueOnly
        } $constantName

        $value | Should -Be '5'
        $value.GetType() | Should -Be ([string])
    }

    It 'Creates array constants from multi-value assignment' {
        $module = Get-Module -Name WPF
        $constantName = "ConstArray_$([guid]::NewGuid().ToString('N'))"

        $value = & $module {
            param($Name)

            Const $Name = 'Red', 'Green', 'Blue'
            Get-Variable -Name $Name -ValueOnly
        } $constantName

        @($value).Count | Should -Be 3
        @($value)[0] | Should -Be 'Red'
        @($value)[1] | Should -Be 'Green'
        @($value)[2] | Should -Be 'Blue'
    }

    It 'Throws if the constant name already exists in caller scope' {
        $module = Get-Module -Name WPF
        $constantName = "ConstDuplicate_$([guid]::NewGuid().ToString('N'))"

        {
            & $module {
                param($Name)

                Const $Name = 1
                Const $Name = 2
            } $constantName
        } | Should -Throw -ExceptionType ([System.Management.Automation.SessionStateException])
    }

    It 'Creates read-only variables when invoked as readonly' {
        $module = Get-Module -Name WPF
        $variableName = "ReadonlyVariable_$([guid]::NewGuid().ToString('N'))"

        $value = & $module {
            param($Name)

            Readonly $Name = 'alpha'
            $variable = Get-Variable -Name $Name
            $variable.Options
        } $variableName

        $value | Should -Be ([System.Management.Automation.ScopedItemOptions]::ReadOnly)
    }

    It 'Creates regular variables when invoked as local' {
        $module = Get-Module -Name WPF
        $localName = "LocalVariable_$([guid]::NewGuid().ToString('N'))"

        $localValue = & $module {
            param($Name)

            Local $Name = 'beta'
            Get-Variable -Name $Name -ValueOnly
        } $localName

        $localValue | Should -Be 'beta'
    }

    It 'Creates global variables when invoked as global' {
        $module = Get-Module -Name WPF
        $variableName = "GlobalVariable_$([guid]::NewGuid().ToString('N'))"

        try {
            & $module {
                param($Name)

                Global $Name = 'root'
            } $variableName

            Get-Variable -Name $variableName -Scope Global -ValueOnly | Should -Be 'root'
        } finally {
            Remove-Variable -Name $variableName -Scope Global -ErrorAction SilentlyContinue
        }
    }
}
