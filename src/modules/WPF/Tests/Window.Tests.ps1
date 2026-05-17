Describe 'Window' -Tag 'Window' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF" -Force
        $script:OriginalAutoCloseValue = $env:WPF_AUTO_CLOSE_SECONDS
    }

    AfterAll {
        $env:WPF_AUTO_CLOSE_SECONDS = $script:OriginalAutoCloseValue
    }

    # NOTE: This test serves as a reminder that shortname resolution inside the DSL
    # scriptblocks works and failures should be treated as regressions. The test itself
    # may not be adequate to catch all edge cases however.
    #
    # Even things as innocuous as adding a new function to the module can cause failures
    # for no apparent reason.
    It 'Should resolve namespaced WPF short type names in nested DSL scriptblocks' {
        $Id = [guid]::NewGuid().ToString('N')

        $Test = [scriptblock]::Create(@"
using namespace System.Windows
using namespace System.Windows.Controls

`$Window = Window "Window_$Id" {
    `$this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen

    ScrollViewer "ScrollViewer_$Id" {
        `$this.VerticalScrollBarVisibility = [ScrollBarVisibility]::Auto
        `$this.HorizontalScrollBarVisibility = [ScrollBarVisibility]::Auto
    }
}

`$Window.WindowStartupLocation | Should -Be -ExpectedValue ([WindowStartupLocation]::CenterScreen)
`$Window.Content | Should -BeOfType [System.Windows.Controls.ScrollViewer]
`$Window.Content.VerticalScrollBarVisibility | Should -Be -ExpectedValue ([ScrollBarVisibility]::Auto)
`$Window.Content.HorizontalScrollBarVisibility | Should -Be -ExpectedValue ([ScrollBarVisibility]::Auto)
"@)

        $Test | Should -Not -Throw
    }

    It 'Should skip block when invoked with negative prefix' {
        $Id = [guid]::NewGuid().ToString('N')

        $WarningPreference = 'SilentlyContinue'
        . "$PSScriptRoot/Helpers/Sync-ModulePreference.ps1"
        Sync-ModulePreference -Name 'WPF' -Include 'WarningPreference'

        $Result = {
            -Window "Window_$Id" {
                Label "Child_$Id" {}
            }
        }

        $Result.Invoke() | Should -BeNullOrEmpty
    }

    It 'Should auto-close on first render when WPF_AUTO_CLOSE_SECONDS is enabled' {
        $env:WPF_AUTO_CLOSE_SECONDS = 0
        $Id = [guid]::NewGuid().ToString('N')

        $Window = Window "Window_$Id" {
            $this.Title = 'AutoClose Env Window'

            # WARNING: ContentRendered doesn't fire if there are no child elements,
            # so we need to add at least one control to trigger the auto-close logic.
            Label "Label_$Id" {
                $this.Content = "This window should auto-close after {0} seconds." -f $AutoCloseSeconds
            }
        }

        { $Window | Show-WPFWindow | Out-Null } | Should -Not -Throw
        $LastDialogCloseReason | Should -Be -ExpectedValue 'AutoClose'
    }

    It 'Should support AutoCloseSeconds 0 by closing immediately after first render' {
        $env:WPF_AUTO_CLOSE_SECONDS = $null
        $Id = [guid]::NewGuid().ToString('N')

        $Test = {
            param([double] $AutoCloseSeconds)

            # WARNING: $PSBoundParameters is not available at runtime in Pester v5 so we have to mock it.
            $PSBoundParameters = @{
                AutoCloseSeconds = $AutoCloseSeconds
            }

            $Window = Window "Window_$Id" {
                $this.Title = 'AutoClose Window'

                # WARNING: ContentRendered doesn't fire if there are no child elements,
                # so we need to add at least one control to trigger the auto-close logic.
                Label "Label_$Id" {
                    $this.Content = "This window should auto-close after {0} seconds." -f $AutoCloseSeconds
                }
            }

            $Window | Show-WPFWindow | Out-Null
        }

        { & $Test -AutoCloseSeconds 0 }  | Should -Not -Throw
        $LastDialogCloseReason | Should -Be -ExpectedValue 'AutoClose'
    }

    It 'Should report user close reason when window is closed without auto-close policy' {
        $env:WPF_AUTO_CLOSE_SECONDS = $null
        $Id = [guid]::NewGuid().ToString('N')

        $Window = Window "Window_$Id" {
            $this.Title = 'User Close Window'

            When Loaded {
                $this.DialogResult = $false
            }
        }

        { $Window | Show-WPFWindow | Out-Null } | Should -Not -Throw
        $LastDialogCloseReason | Should -Be -ExpectedValue 'User'
    }

    It 'Should ignore invalid WPF_AUTO_CLOSE_SECONDS values' {
        $env:WPF_AUTO_CLOSE_SECONDS = 'bogus'
        $Id = [guid]::NewGuid().ToString('N')

        $Window = Window "Window_$Id" {
            $this.Title = 'Invalid AutoClose Env Window'
        }

        # Creation should not fail even when env fallback is invalid.
        $Window | Should -BeOfType [System.Windows.Window]
    }
}
