Describe 'Show-WPFWindow' -Tag 'Show-WPFWindow' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    BeforeAll {
        $script:OriginalAutoCloseValue = $env:WPF_AUTO_CLOSE_SECONDS
    }

    AfterAll {
        $env:WPF_AUTO_CLOSE_SECONDS = $script:OriginalAutoCloseValue
    }

    BeforeEach {
        $env:WPF_AUTO_CLOSE_SECONDS = $null

        InModuleScope WPF {
            Clear-WPFControlRegistry
        }
    }

    AfterEach {
        InModuleScope WPF {
            Clear-WPFControlRegistry
        }
        Remove-Variable -Name ShowWindowClosingCount -Scope Global -ErrorAction SilentlyContinue
    }

    It 'Should not trigger a second close pass after ShowDialog returns' {
        $env:WPF_AUTO_CLOSE_SECONDS = 0
        $global:ShowWindowClosingCount = 0
        $WindowName = 'Window'

        $Window = Window $WindowName {
            Label 'WindowContent' {
                $this.Content = 'Auto-close render content'
            }

            When Closing {
                $null = Reference $WindowName -ErrorAction Stop
                $global:ShowWindowClosingCount++
            }
        }

        { $Window | Show-WPFWindow | Out-Null } | Should -Not -Throw
        $global:ShowWindowClosingCount | Should -Be 1
    }

    It 'Should not clear parent registry when showing a helper dialog' {
        $env:WPF_AUTO_CLOSE_SECONDS = 0
        $WindowName = 'Window'

        $MainWindow = Window $WindowName {
            $this.Title = 'Main'
        }

        $ContextId = [string] $MainWindow.PSObject.Properties['_WPFContextId'].Value
        $Dialog = [System.Windows.Window]::new()
        $Dialog.Title = 'Helper'
        $Dialog.Content = [System.Windows.Controls.TextBlock]::new()
        $Dialog.Content.Text = 'Auto-close helper dialog'

        { $Dialog | Show-WPFWindow | Out-Null } | Should -Not -Throw

        $ResolvedMainWindow = Reference $WindowName -ContextId $ContextId
        $ResolvedMainWindow | Should -BeExactly -ExpectedValue $MainWindow
    }

    It 'Should honor WPF_AUTO_CLOSE_SECONDS for direct windows shown with Show-WPFWindow' {
        $env:WPF_AUTO_CLOSE_SECONDS = 0

        $Dialog = [System.Windows.Window]::new()
        $Dialog.Title = 'Automation dialog'
        $Dialog.Content = [System.Windows.Controls.TextBlock]::new()
        $Dialog.Content.Text = 'Auto-close me'

        { $Dialog | Show-WPFWindow | Out-Null } | Should -Not -Throw
        $LastDialogCloseReason | Should -Be -ExpectedValue 'AutoClose'
    }
}
