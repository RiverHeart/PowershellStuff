Describe 'Border DSL' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
        $WarningPreference = 'SilentlyContinue'
    }

    It 'Should create and auto-attach a named border' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()
        $psVars = New-WPFVariableList -InputObject $Parent

        $Result = {
            Border "Border_$Id" {
                $this.Padding = 4
            }
        }.InvokeWithContext($null, $PSVars)

        @($Result).Count | Should -Be -ExpectedValue 0
        $Parent.Content | Should -BeOfType [System.Windows.Controls.Border]
        $Parent.Content.Name | Should -Be -ExpectedValue "Border_$Id"
        $Parent.Content.Padding.Left | Should -Be -ExpectedValue 4
    }

    It 'Should support nameless border syntax' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Controls.Button]::new()
        $psVars = New-WPFVariableList -InputObject $Parent

        $Result = {
            Border {
                Label "BorderChild_$Id" {}
            }
        }.InvokeWithContext($null, $PSVars)

        @($Result).Count | Should -Be -ExpectedValue 0
        $Parent.Content | Should -BeOfType [System.Windows.Controls.Border]
        $Parent.Content.Child | Should -BeOfType [System.Windows.Controls.Label]
        $Parent.Content.Child.Name | Should -Be -ExpectedValue "BorderChild_$Id"
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')
        $Parent = [System.Windows.Window]::new()

        $WarningPreference = 'SilentlyContinue'
        . "$PSScriptRoot/Helpers/Sync-ModulePreference.ps1"
        Sync-ModulePreference -Name 'WPF' -Include 'WarningPreference'

        $Result = {
            -Border "Border_$Id" {
                $this.Padding = 4
            }
        }.Invoke()

        $Parent.Content | Should -BeNullOrEmpty
    }
}

Describe 'Find-WPFChildNode' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
        $WarningPreference = 'SilentlyContinue'
    }

    It 'Should return the same object when node matches requested type' {
        $Path = [System.Windows.Shapes.Path]::new()

        $Found = Find-WPFChildNode -Node $Path -Type ([System.Windows.Shapes.Path])

        $Found | Should -BeExactly -ExpectedValue $Path
    }

    It 'Should find first matching descendant by type' {
        $First = [System.Windows.Shapes.Path]::new()
        $Second = [System.Windows.Shapes.Path]::new()
        $Border = [System.Windows.Controls.Border]::new()
        $Panel = [System.Windows.Controls.StackPanel]::new()

        $Border.Child = $First
        $null = $Panel.Children.Add($Border)
        $null = $Panel.Children.Add($Second)

        $Found = Find-WPFChildNode -Node $Panel -Type ([System.Windows.Shapes.Path])

        $Found | Should -BeExactly -ExpectedValue $First
    }

    It 'Should return all matching descendants with -All' {
        $First = [System.Windows.Shapes.Path]::new()
        $Second = [System.Windows.Shapes.Path]::new()
        $Panel = [System.Windows.Controls.StackPanel]::new()

        $null = $Panel.Children.Add($First)
        $null = $Panel.Children.Add([System.Windows.Controls.Label]::new())
        $null = $Panel.Children.Add($Second)

        $Found = Find-WPFChildNode -Node $Panel -Type ([System.Windows.Shapes.Path]) -All

        @($Found).Count | Should -Be -ExpectedValue 2
        $Found[0] | Should -BeExactly -ExpectedValue $First
        $Found[1] | Should -BeExactly -ExpectedValue $Second
    }

    It 'Should return null when no matching node exists' {
        $Label = [System.Windows.Controls.Label]::new()

        $Found = Find-WPFChildNode -Node $Label -Type ([System.Windows.Shapes.Path])

        $Found | Should -BeNullOrEmpty
    }
}

Describe 'When' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
        $WarningPreference = 'SilentlyContinue'
    }

    It 'Should inject this as the current object when event fires' {
        $global:WhenThisName = $null

        $Name = "WhenButton_$([guid]::NewGuid().ToString('N'))"
        $Button = Button $Name {
            When Click {
                $global:WhenThisName = $this.Name
            }
        }

        $Button.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))

        $global:WhenThisName | Should -Be -ExpectedValue $Name

        Remove-Variable -Name WhenThisName -Scope Global -ErrorAction SilentlyContinue
    }
}

Describe 'Set-WPFWindowFullScreen' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
        $WarningPreference = 'SilentlyContinue'
    }

    It 'Should transition through Normal when enabling fullscreen from a maximized window' {
        InModuleScope WPF {
            $State = [pscustomobject]@{
                IsFullScreen   = $false
                OldWindowStyle = $null
                OldWindowState = $null
                OldResizeMode  = $null
            }

            $History = [System.Collections.Generic.List[object]]::new()

            $Window = [pscustomobject]@{
                WindowStyle = [WindowStyle]::SingleBorderWindow
                ResizeMode  = [ResizeMode]::CanResize
                Tag         = $State
                _WindowState = [WindowState]::Maximized
            }

            Mock -CommandName Reference -MockWith {
                $Window
            }

            $Window | Add-Member -MemberType ScriptProperty -Name WindowState -Value {
                $this._WindowState
            } -SecondValue {
                param($value)
                $History.Add($value)
                $this._WindowState = $value
            } -Force

            Set-WPFWindowFullScreen -IsFullScreen $true

            $State.IsFullScreen | Should -BeTrue
            $Window.WindowStyle | Should -Be -ExpectedValue ([WindowStyle]::None)
            $Window.ResizeMode | Should -Be -ExpectedValue ([ResizeMode]::NoResize)
            @($History) | Should -Be -ExpectedValue @([WindowState]::Normal, [WindowState]::Maximized)
        }
    }

    It 'Should not overwrite old restore state when called repeatedly with IsFullScreen=true' {
        InModuleScope WPF {
            $State = [pscustomobject]@{
                IsFullScreen   = $false
                OldWindowStyle = $null
                OldWindowState = $null
                OldResizeMode  = $null
            }

            $Window = [pscustomobject]@{
                WindowStyle = [WindowStyle]::SingleBorderWindow
                WindowState = [WindowState]::Normal
                ResizeMode  = [ResizeMode]::CanResize
                Tag         = $State
            }

            Mock -CommandName Reference -MockWith {
                $Window
            }

            Set-WPFWindowFullScreen -IsFullScreen $true

            # Simulate mutated fullscreen values before an accidental duplicate call.
            $Window.WindowStyle = [WindowStyle]::None
            $Window.WindowState = [WindowState]::Maximized
            $Window.ResizeMode  = [ResizeMode]::NoResize

            Set-WPFWindowFullScreen -IsFullScreen $true

            $State.OldWindowStyle | Should -Be -ExpectedValue ([WindowStyle]::SingleBorderWindow)
            $State.OldWindowState | Should -Be -ExpectedValue ([WindowState]::Normal)
            $State.OldResizeMode | Should -Be -ExpectedValue ([ResizeMode]::CanResize)
        }
    }
}
