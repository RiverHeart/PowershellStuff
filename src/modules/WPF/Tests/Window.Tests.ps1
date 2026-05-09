Describe 'Window' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF" -Force
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
}
