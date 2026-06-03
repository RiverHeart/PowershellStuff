Describe 'Command' -Tag 'Command' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    It 'Should skip block when invoked with negative prefix' {
        $WarningPreference = 'SilentlyContinue'
        . "$PSScriptRoot/Helpers/Sync-ModulePreference.ps1"
        Sync-ModulePreference -Name 'WPF' -Include 'WarningPreference'

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
