Describe 'Register-WPFObject' -Tag 'Register-WPFObject' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../WPF.psd1" -Force
    }

    BeforeEach {
        InModuleScope WPF {
            Clear-WPFControlRegistry
        }
    }

    It 'Should register an object retrievable by name' {
        $Window = [System.Windows.Window]::new()
        Register-WPFObject -Name 'Window' -InputObject $Window -Overwrite

        $Button = [System.Windows.Controls.Button]::new()
        Register-WPFObject -Name 'SaveButton' -InputObject $Button -ContextId ([string] $Window.PSObject.Properties['_WPFContextId'].Value)

        (Reference 'SaveButton' -ContextId ([string] $Window.PSObject.Properties['_WPFContextId'].Value)) |
            Should -BeExactly -ExpectedValue $Button
    }

    It 'Should not register an object named __Nameless__' {
        $Window = [System.Windows.Window]::new()
        Register-WPFObject -Name 'Window' -InputObject $Window -Overwrite

        $Button = [System.Windows.Controls.Button]::new()
        Register-WPFObject -Name '__Nameless__' -InputObject $Button -ContextId ([string] $Window.PSObject.Properties['_WPFContextId'].Value)

        { Reference '__Nameless__' -ErrorAction Stop } | Should -Throw
    }

    It 'Should not overwrite an existing registration by default' {
        $Window = [System.Windows.Window]::new()
        Register-WPFObject -Name 'Window' -InputObject $Window -Overwrite

        $FirstButton = [System.Windows.Controls.Button]::new()
        $SecondButton = [System.Windows.Controls.Button]::new()
        $ContextId = [string] $Window.PSObject.Properties['_WPFContextId'].Value

        Register-WPFObject -Name 'SaveButton' -InputObject $FirstButton -ContextId $ContextId
        Register-WPFObject -Name 'SaveButton' -InputObject $SecondButton -ContextId $ContextId -ErrorAction SilentlyContinue

        (Reference 'SaveButton' -ContextId $ContextId) | Should -BeExactly -ExpectedValue $FirstButton
    }

    It 'Should overwrite an existing registration when -Overwrite is used' {
        $Window = [System.Windows.Window]::new()
        Register-WPFObject -Name 'Window' -InputObject $Window -Overwrite

        $FirstButton = [System.Windows.Controls.Button]::new()
        $SecondButton = [System.Windows.Controls.Button]::new()
        $ContextId = [string] $Window.PSObject.Properties['_WPFContextId'].Value

        Register-WPFObject -Name 'SaveButton' -InputObject $FirstButton -ContextId $ContextId
        Register-WPFObject -Name 'SaveButton' -InputObject $SecondButton -ContextId $ContextId -Overwrite

        (Reference 'SaveButton' -ContextId $ContextId) | Should -BeExactly -ExpectedValue $SecondButton
    }

    It 'Should activate the context when registering a Window' {
        $FirstWindow = [System.Windows.Window]::new()
        Register-WPFObject -Name 'FirstWindow' -InputObject $FirstWindow

        $SecondWindow = [System.Windows.Window]::new()
        Register-WPFObject -Name 'SecondWindow' -InputObject $SecondWindow

        $ActiveContextId = InModuleScope WPF { (Get-WPFControlRegistry).ActiveContextId }
        $ActiveContextId | Should -Be ([string] $SecondWindow.PSObject.Properties['_WPFContextId'].Value)
    }

    It 'Should return the input object when -PassThru is used' {
        $Window = [System.Windows.Window]::new()
        Register-WPFObject -Name 'Window' -InputObject $Window -Overwrite

        $Button = [System.Windows.Controls.Button]::new()
        $Result = Register-WPFObject -Name 'SaveButton' -InputObject $Button -ContextId ([string] $Window.PSObject.Properties['_WPFContextId'].Value) -PassThru

        $Result | Should -BeExactly -ExpectedValue $Button
    }

    It 'Should not return anything when -PassThru is not used' {
        $Window = [System.Windows.Window]::new()
        $Result = Register-WPFObject -Name 'Window' -InputObject $Window -Overwrite

        $Result | Should -BeNullOrEmpty
    }

    It 'Should accept input from the pipeline' {
        $Window = [System.Windows.Window]::new()
        Register-WPFObject -Name 'Window' -InputObject $Window -Overwrite

        $Button = [System.Windows.Controls.Button]::new()
        $ContextId = [string] $Window.PSObject.Properties['_WPFContextId'].Value
        $Button | Register-WPFObject -Name 'SaveButton' -ContextId $ContextId

        (Reference 'SaveButton' -ContextId $ContextId) | Should -BeExactly -ExpectedValue $Button
    }

    It 'Should not throw when -Type is not specified (regression: raw CLR type name must not be sent to Add-WPFType)' {
        $Window = [System.Windows.Window]::new()

        { Register-WPFObject -Name 'Window' -InputObject $Window -Overwrite -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Should tag the object with the custom DSL type when -Type is specified' {
        $Window = [System.Windows.Window]::new()
        Register-WPFObject -Name 'Window' -InputObject $Window -Overwrite

        $Button = [System.Windows.Controls.Button]::new()
        $ContextId = [string] $Window.PSObject.Properties['_WPFContextId'].Value
        Register-WPFObject -Name 'SaveButton' -InputObject $Button -ContextId $ContextId -Type Control

        $Button.PSObject.TypeNames | Should -Contain 'Custom.WPF.Control'
    }

    It 'Should reject names containing characters other than letters, numbers, and underscores' {
        $Window = [System.Windows.Window]::new()

        { Register-WPFObject -Name 'Bad-Name' -InputObject $Window -ErrorAction Stop } | Should -Throw
    }
}
