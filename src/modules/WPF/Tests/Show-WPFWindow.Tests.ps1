Describe 'Show-WPFWindow' -Tag 'Show-WPFWindow' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
        $script:OriginalSmokeValue = [Environment]::GetEnvironmentVariable('WPF_SMOKE_TEST')
    }

    BeforeEach {
        InModuleScope WPF {
            Clear-WPFControlRegistry
        }
        [Environment]::SetEnvironmentVariable('WPF_SMOKE_TEST', '1')
    }

    AfterEach {
        [Environment]::SetEnvironmentVariable('WPF_SMOKE_TEST', $script:OriginalSmokeValue)
        InModuleScope WPF {
            Clear-WPFControlRegistry
        }
        Remove-Variable -Name ShowWindowClosingCount -Scope Global -ErrorAction SilentlyContinue
    }

    It 'Should not trigger a second close pass after ShowDialog returns' {
        $global:ShowWindowClosingCount = 0
        $WindowName = 'Window'

        $Window = Window $WindowName {
            When Closing {
                $null = Reference $WindowName -ErrorAction Stop
                $global:ShowWindowClosingCount++
            }
        }

        { $Window | Show-WPFWindow | Out-Null } | Should -Not -Throw
        $global:ShowWindowClosingCount | Should -Be 1
    }

    It 'Should not clear parent registry when showing a helper dialog' {
        $WindowName = 'Window'

        $MainWindow = Window $WindowName {
            $this.Title = 'Main'
        }

        $ContextId = [string] $MainWindow.PSObject.Properties['_WPFContextId'].Value
        $Dialog = [System.Windows.Window]::new()
        $Dialog.Title = 'Helper'

        { $Dialog | Show-WPFWindow | Out-Null } | Should -Not -Throw

        $ResolvedMainWindow = Reference $WindowName -ContextId $ContextId
        $ResolvedMainWindow | Should -BeExactly -ExpectedValue $MainWindow
    }
}
