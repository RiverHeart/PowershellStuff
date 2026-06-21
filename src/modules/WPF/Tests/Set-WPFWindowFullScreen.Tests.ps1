Describe 'Set-WPFWindowFullScreen' -Tag 'Set-WPFWindowFullScreen' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    BeforeAll {
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

            $MockWindow = [pscustomobject]@{
                WindowStyle = [WindowStyle]::SingleBorderWindow
                ResizeMode  = [ResizeMode]::CanResize
                Tag         = $State
                _WindowState = [WindowState]::Maximized
            }

            Mock -CommandName Reference -MockWith {
                $MockWindow
            }

            $MockWindow | Add-Member -MemberType ScriptProperty -Name WindowState -Value {
                $this._WindowState
            } -SecondValue {
                param($value)
                $History.Add($value)
                $this._WindowState = $value
            } -Force

            Set-WPFWindowFullScreen -IsFullScreen $true

            $State.IsFullScreen | Should -BeTrue
            $MockWindow.WindowStyle | Should -Be -ExpectedValue ([WindowStyle]::None)
            $MockWindow.ResizeMode | Should -Be -ExpectedValue ([ResizeMode]::NoResize)
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

            $MockWindow = [pscustomobject]@{
                WindowStyle = [WindowStyle]::SingleBorderWindow
                WindowState = [WindowState]::Normal
                ResizeMode  = [ResizeMode]::CanResize
                Tag         = $State
            }

            Mock -CommandName Reference -MockWith {
                $MockWindow
            }

            Set-WPFWindowFullScreen -IsFullScreen $true

            # Simulate mutated fullscreen values before an accidental duplicate call.
            $MockWindow.WindowStyle = [WindowStyle]::None
            $MockWindow.WindowState = [WindowState]::Maximized
            $MockWindow.ResizeMode  = [ResizeMode]::NoResize

            Set-WPFWindowFullScreen -IsFullScreen $true

            $State.OldWindowStyle | Should -Be -ExpectedValue ([WindowStyle]::SingleBorderWindow)
            $State.OldWindowState | Should -Be -ExpectedValue ([WindowState]::Normal)
            $State.OldResizeMode | Should -Be -ExpectedValue ([ResizeMode]::CanResize)
        }
    }

    It 'Should collapse and restore App content host margin when toggling fullscreen' {
        InModuleScope WPF {
            $State = [pscustomobject]@{
                IsFullScreen   = $false
                OldWindowStyle = $null
                OldWindowState = $null
                OldResizeMode  = $null
            }

            $ContentHost = [System.Windows.Controls.Grid]::new()
            $ContentHost.Margin = [System.Windows.Thickness]::new(5)

            $MockWindow = [pscustomobject]@{
                WindowStyle = [WindowStyle]::SingleBorderWindow
                WindowState = [WindowState]::Normal
                ResizeMode  = [ResizeMode]::CanResize
                Tag         = $State
            }
            $MockWindow | Add-Member -NotePropertyName _WPFAppContent -NotePropertyValue $ContentHost -Force

            Set-WPFWindowFullScreen -IsFullScreen $true -Window $MockWindow

            $ContentHost.Margin | Should -Be -ExpectedValue ([System.Windows.Thickness]::new(0))
            $State.OldAppContentMargin | Should -Be -ExpectedValue ([System.Windows.Thickness]::new(5))

            Set-WPFWindowFullScreen -IsFullScreen $false -Window $MockWindow

            $ContentHost.Margin | Should -Be -ExpectedValue ([System.Windows.Thickness]::new(5))
        }
    }

    It 'Should resolve the default window by explicit ContextId for async-safe callbacks' {
        InModuleScope WPF {
            $State = [pscustomobject]@{
                IsFullScreen   = $false
                OldWindowStyle = $null
                OldWindowState = $null
                OldResizeMode  = $null
            }

            $MockWindow = [pscustomobject]@{
                WindowStyle = [WindowStyle]::SingleBorderWindow
                WindowState = [WindowState]::Normal
                ResizeMode  = [ResizeMode]::CanResize
                Tag         = $State
            }

            Mock -CommandName Reference -ParameterFilter {
                $Name -eq 'Window' -and $ContextId -eq 'ctx-fullscreen'
            } -MockWith {
                $MockWindow
            }

            Set-WPFWindowFullScreen -IsFullScreen $true -ContextId 'ctx-fullscreen'

            Assert-MockCalled -CommandName Reference -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'Window' -and $ContextId -eq 'ctx-fullscreen'
            }
            $State.IsFullScreen | Should -BeTrue
        }
    }
}
