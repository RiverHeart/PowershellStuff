Describe 'Command' -Tag 'Command' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../WPF.psd1" -Force
        $env:SuppressWPFDisabledBlockWarning = $true
    }

    It 'Should skip block when invoked with negative prefix' {
        $Result = {
            -Command 'About' {
                Execute { Write-Host "Should not run"
             }
            }
        }.Invoke()

        $Result | Should -BeNullOrEmpty
    }

    It 'Should assign a RelayCommand when only Execute is supplied' {
        $Parent = [System.Windows.Controls.MenuItem]::new()
        $PSVars = New-WPFVariableList -InputObject $Parent

        {
            Command 'DoThing' {
                Execute { $null = $true }
            }
        }.InvokeWithContext($null, $PSVars)

        $Parent.Command | Should -BeOfType [RelayCommand]
    }

    It 'Should assign a RelayCommand with CanExecute when both are supplied' {
        $Parent = [System.Windows.Controls.MenuItem]::new()
        $PSVars = New-WPFVariableList -InputObject $Parent

        {
            Command 'DoThing' {
                Execute { $null = $true }
                CanExecute { $true }
            }
        }.InvokeWithContext($null, $PSVars)

        $Parent.Command | Should -BeOfType [RelayCommand]
        $Parent.Command.CanExecute($null) | Should -BeTrue
    }

    It 'Should return a reusable command definition outside a control scriptblock' {
        $Definition = Command 'DoThing' {
            Execute { $null = $true }
            CanExecute { $true }
        }

        $Definition.PSObject.TypeNames | Should -Contain 'WPF.CommandDefinition'
        $Definition.Name | Should -Be 'DoThing'
        $Definition.Command | Should -Be $null
    }

    It 'Should attach the same command instance to multiple controls' {
        $Definition = Command 'DoThing' {
            Execute { $null = $true }
            CanExecute { $true }
        }
        $FirstParent = [System.Windows.Controls.Button]::new()
        $SecondParent = [System.Windows.Controls.Button]::new()

        {
            Command $Definition
        }.InvokeWithContext($null, (New-WPFVariableList -InputObject $FirstParent))
        {
            Command $Definition
        }.InvokeWithContext($null, (New-WPFVariableList -InputObject $SecondParent))

        $FirstParent.Command | Should -BeOfType [RelayCommand]
        [object]::ReferenceEquals($FirstParent.Command, $SecondParent.Command) | Should -BeTrue
        [object]::ReferenceEquals($Definition.Command, $FirstParent.Command) | Should -BeTrue
    }

    It 'Should attach a reusable command with a gesture' {
        InModuleScope WPF {
            Clear-WPFControlRegistry
        }

        $Window = [System.Windows.Window]::new()
        Register-WPFObject -Name 'Window' -InputObject $Window -Overwrite
        $Definition = Command 'DoThing' {
            Execute { $null = $true }
        }
        $Parent = [System.Windows.Controls.MenuItem]::new()

        {
            Command $Definition 'Ctrl+P'
        }.InvokeWithContext($null, (New-WPFVariableList -InputObject $Parent))

        $Parent.Command | Should -BeOfType [RelayCommand]
        $Parent.InputGestureText | Should -Be 'Ctrl+P'
        $Window.InputBindings.Count | Should -Be 1
        $Window.InputBindings[0].Command | Should -BeExactly $Parent.Command
    }

    It 'Should add a CommandBinding and assign routed command when BoundTo is supplied' {
        InModuleScope WPF {
            Clear-WPFControlRegistry
        }

        $Window = [System.Windows.Window]::new()
        Register-WPFObject -Name 'Window' -InputObject $Window -Overwrite

        $Parent = [System.Windows.Controls.MenuItem]::new()
        $PSVars = New-WPFVariableList -InputObject $Parent

        {
            Command 'Open' {
                BoundTo 'Window'
                Execute { $null = $true }
            }
        }.InvokeWithContext($null, $PSVars)

        $Parent.Command | Should -BeOfType [System.Windows.Input.ICommand]
        $Window.CommandBindings.Count | Should -BeGreaterThan 0
    }

    It 'Should add a CommandBinding with -BoundTo' {
        InModuleScope WPF {
            Clear-WPFControlRegistry
        }

        $Window = [System.Windows.Window]::new()
        Register-WPFObject -Name 'Window' -InputObject $Window -Overwrite

        $Parent = [System.Windows.Controls.MenuItem]::new()
        $PSVars = New-WPFVariableList -InputObject $Parent

        {
            Command 'Open' -BoundTo 'Window' {
                $null = $true
            }
        }.InvokeWithContext($null, $PSVars)

        $Parent.Command | Should -BeOfType [System.Windows.Input.ICommand]
        $Window.CommandBindings.Count | Should -BeGreaterThan 0
    }

    It 'Should show gesture text for built-in command when explicit gesture is provided' {
        InModuleScope WPF {
            Clear-WPFControlRegistry
        }

        $Window = [System.Windows.Window]::new()
        Register-WPFObject -Name 'Window' -InputObject $Window -Overwrite

        $Parent = [System.Windows.Controls.MenuItem]::new()
        $PSVars = New-WPFVariableList -InputObject $Parent

        {
            Command 'SaveAs' 'Ctrl+Shift+S' -BoundTo 'Window' {
                $null = $true
            }
        }.InvokeWithContext($null, $PSVars)

        $Parent.Command | Should -BeOfType [System.Windows.Input.ICommand]
        $Parent.InputGestureText | Should -Be -ExpectedValue 'Ctrl+Shift+S'
        $Window.CommandBindings.Count | Should -BeGreaterThan 0
    }

    It 'Should create a custom routed command with a single gesture' {
        InModuleScope WPF {
            Clear-WPFControlRegistry
        }

        $Window = [System.Windows.Window]::new()
        Register-WPFObject -Name 'Window' -InputObject $Window -Overwrite

        $Parent = [System.Windows.Controls.MenuItem]::new()
        $PSVars = New-WPFVariableList -InputObject $Parent

        {
            Command 'CustomSaveAs' 'Ctrl+Shift+S' -BoundTo 'Window' {
                $null = $true
            }
        }.InvokeWithContext($null, $PSVars)

        $Parent.Command | Should -BeOfType [System.Windows.Input.ICommand]
        $Window.CommandBindings.Count | Should -BeGreaterThan 0
    }

    It 'Should write CommandSpec to the parent spec bag' {
        $Parent = [System.Windows.Controls.MenuItem]::new()
        $PSVars = New-WPFVariableList -InputObject $Parent

        {
            Command 'DoThing' {
                Execute { $null = $true }
            }
        }.InvokeWithContext($null, $PSVars)

        $Parent.PSObject.Properties['WPFSpec'] | Should -Not -BeNullOrEmpty
        $Parent.WPFSpec['Command'] | Should -BeExactly -ExpectedValue $Parent.Command
    }

    It 'Should error when Execute block is missing' {
        $Parent = [System.Windows.Controls.MenuItem]::new()
        $PSVars = New-WPFVariableList -InputObject $Parent
        $ErrorActionPreference = 'Stop'

        { {
            Command 'DoThing' -ErrorAction Stop {
                CanExecute { $true }
            }
        }.InvokeWithContext($null, $PSVars) } | Should -Throw
    }

    It 'Should error when CanExecute and BoundTo are both supplied' {
        InModuleScope WPF {
            Clear-WPFControlRegistry
        }

        $Window = [System.Windows.Window]::new()
        Register-WPFObject -Name 'Window' -InputObject $Window -Overwrite

        $Parent = [System.Windows.Controls.MenuItem]::new()
        $PSVars = New-WPFVariableList -InputObject $Parent
        $ErrorActionPreference = 'Stop'

        { {
            Command 'Open' -ErrorAction Stop {
                BoundTo 'Window'
                Execute { $null = $true }
                CanExecute { $true }
            }
        }.InvokeWithContext($null, $PSVars) } | Should -Throw
    }

    It 'Should create a RelayCommand with KeyBinding on Window when gesture is supplied without BoundTo' {
        InModuleScope WPF {
            Clear-WPFControlRegistry
        }

        $Window = [System.Windows.Window]::new()
        Register-WPFObject -Name 'Window' -InputObject $Window -Overwrite

        $Parent = [System.Windows.Controls.MenuItem]::new()
        $PSVars = New-WPFVariableList -InputObject $Parent

        {
            Command 'SaveAs' 'Ctrl+Shift+S' {
                $null = $true
            }
        }.InvokeWithContext($null, $PSVars)

        $Parent.Command | Should -BeOfType [RelayCommand]
        $Parent.InputGestureText | Should -Be 'Ctrl+Shift+S'
        $Window.InputBindings.Count | Should -Be 1
        $Window.InputBindings[0] | Should -BeOfType [System.Windows.Input.KeyBinding]
    }
}
