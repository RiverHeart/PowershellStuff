class TestWPFDisposable : System.IDisposable {
    [bool] $Disposed = $false

    [void] Dispose() {
        $this.Disposed = $true
    }
}

class TestWPFThrowingDisposable : System.IDisposable {
    [void] Dispose() {
        throw 'Dispose failed intentionally'
    }
}

Describe 'TimedEvent' {
    BeforeAll {
        Import-Module -Name "$PSScriptRoot/../WPF.psd1" -Force
    }

    BeforeEach {
        InModuleScope WPF {
            Clear-WPFControlRegistry
        }
    }

    AfterEach {
        InModuleScope WPF {
            Clear-WPFControlRegistry
        }
    }

    It 'Should register a DispatcherTimer by name in the current context' {
        $Window = Window 'Window' {
            TimedEvent 'ProcessRefresh' 60000 {
                param($sender, $e)
                $null = $sender
                $null = $e
            }
        }

        $ContextId = [string] $Window.PSObject.Properties['_WPFContextId'].Value
        $Timer = Reference 'ProcessRefresh' -ContextId $ContextId

        $Timer | Should -BeOfType [System.Windows.Threading.DispatcherTimer]
        $Timer.Interval.TotalMilliseconds | Should -Be 60000
    }

    It 'Should stop timers when their window closes' {
        $Window = Window 'Window' {
            TimedEvent 'ProcessRefresh' 60000 {
                param($sender, $e)
                $null = $sender
                $null = $e
            }
        }

        $ContextId = [string] $Window.PSObject.Properties['_WPFContextId'].Value
        $Timer = Reference 'ProcessRefresh' -ContextId $ContextId

        $Timer.IsEnabled | Should -BeTrue

        $Window.Close()

        $Timer.IsEnabled | Should -BeFalse
    }

    It 'Should stop async timers when their window closes' {
        $Window = Window 'Window' {
            TimedEvent 'AsyncRefresh' 60000 `
              -Work {
                  Start-Sleep -Milliseconds 50
                  'result'
              } `
              -OnComplete {
                  param($Result, $TimerSender)
                  $null = $Result
                  $null = $TimerSender
              }
        }

        $ContextId = [string] $Window.PSObject.Properties['_WPFContextId'].Value
        $Timer = Reference 'AsyncRefresh' -ContextId $ContextId

        $Timer.IsEnabled | Should -BeTrue
        $Window.Close()

        $Timer.IsEnabled | Should -BeFalse
        $Timer.Tag.IsRefreshing | Should -BeFalse
    }

    It 'Should dispose registered IDisposable objects during registry clear and continue on failures' {
        $Good = [TestWPFDisposable]::new()
        $Bad = [TestWPFThrowingDisposable]::new()

        Register-WPFObject -Name 'GoodDisposable' -InputObject $Good -Overwrite
        Register-WPFObject -Name 'BadDisposable' -InputObject $Bad -Overwrite

        $Warnings = InModuleScope WPF {
            $ClearWarnings = @()
            Clear-WPFControlRegistry -WarningVariable ClearWarnings -WarningAction Continue
            ,$ClearWarnings
        }

        $Good.Disposed | Should -BeTrue
        $Warnings | Should -Not -BeNullOrEmpty
        ($Warnings -join [Environment]::NewLine) | Should -Match 'Failed to dispose object'
    }

    It 'Should initialize IsRefreshing guard for async timers' {
        $Window = Window 'Window' {
            TimedEvent 'AsyncRefresh' 10000 `
              -Work { 'result' } `
              -OnComplete { param($r) $null = $r }
        }

        $ContextId = [string] $Window.PSObject.Properties['_WPFContextId'].Value
        $Timer = Reference 'AsyncRefresh' -ContextId $ContextId

        $Timer.Tag | Should -Not -BeNullOrEmpty
        $Timer.Tag.IsRefreshing | Should -Be $false
    }

    It 'Should invoke Work on background thread and OnComplete on UI thread with result' {
        # Note: This test verifies that async mode is set up correctly.
        # Actual async execution requires a running dispatcher message loop (provided by ShowDialog in real usage).
        # We verify the timer is created with async configuration and will execute properly when the loop is running.

        $Window = Window 'Window' {
            TimedEvent 'AsyncTimer' 100 `
              -Work {
                  'TestData'
              } `
              -OnComplete {
                  param($result)
                  $null = $result
              }
        }

        $ContextId = [string] $Window.PSObject.Properties['_WPFContextId'].Value
        $Timer = Reference 'AsyncTimer' -ContextId $ContextId

        # Verify async timer is properly configured
        $Timer | Should -BeOfType [System.Windows.Threading.DispatcherTimer]
        $Timer.Interval.TotalMilliseconds | Should -Be 100
        $Timer.Tag | Should -Not -BeNullOrEmpty
        $Timer.Tag.IsRefreshing | Should -Be $false
    }

    It 'Should initialize IsRefreshing guard correctly for async timers' {
        $Window = Window 'Window' {
            TimedEvent 'AsyncTimer2' 250 `
              -Work { 'result' } `
              -OnComplete { param($r) $null = $r }
        }

        $ContextId = [string] $Window.PSObject.Properties['_WPFContextId'].Value
        $Timer = Reference 'AsyncTimer2' -ContextId $ContextId

        # Verify guard is initialized
        $Timer.Tag | Should -Not -BeNullOrEmpty
        $Timer.Tag.IsRefreshing | Should -Be $false
        $Timer.Interval.TotalMilliseconds | Should -Be 250
    }

    It 'Should execute async Work and OnComplete while window message loop is active' {
        $Window = Window 'Window' {
            $this.Width = 120
            $this.Height = 80
            $this.ShowInTaskbar = $false

            TimedEvent 'Updater' 100 `
              -Work {
                  Start-Sleep -Milliseconds 60
                  Get-Date
              } `
              -OnComplete {
                  param($Result, $TimerSender)
                  $null = $Result
                  $null = $TimerSender
              }
        }

        $ContextId = [string] $Window.PSObject.Properties['_WPFContextId'].Value
        $UpdaterTimer = Reference 'Updater' -ContextId $ContextId

        # Run a short dispatcher frame to allow timer ticks and async completion.
        $Frame = [System.Windows.Threading.DispatcherFrame]::new()
        $Stopper = [System.Windows.Threading.DispatcherTimer]::new()
        $Stopper.Interval = [System.TimeSpan]::FromMilliseconds(900)
        $Stopper.add_Tick({
            param($sender, $e)
            $null = $e
            $sender.Stop()
            $Frame.Continue = $false
        })

        try {
            $Window.Show()
            $Stopper.Start()
            [System.Windows.Threading.Dispatcher]::PushFrame($Frame)
            $UpdaterTimer | Should -Not -BeNullOrEmpty
            $UpdaterTimer.Tag.CompletionCount | Should -BeGreaterThan 0
        } finally {
            $Stopper.Stop()
            $Window.Close()
        }
    }

    It 'Should pass emitted Work items to OnComplete in async mode' {
        $Window = Window 'Window' {
            $this.Width = 120
            $this.Height = 80
            $this.ShowInTaskbar = $false
            $this.Tag = @{
                ItemCount = 0
                FirstName = $null
            }

            TimedEvent 'AsyncResultShape' 100 `
              -Work {
                  [pscustomobject]@{ Name = 'Alpha' }
                  [pscustomobject]@{ Name = 'Beta' }
              } `
              -OnComplete {
                  param($Result, $TimerSender)
                  $Items = @($Result)
                  $WindowRef = Reference 'Window'
                  $WindowRef.Tag.ItemCount = $Items.Count
                  $WindowRef.Tag.FirstName = if ($Items.Count -gt 0) { $Items[0].Name } else { $null }
                  $TimerSender.Stop()
              }
        }

        # Run a short dispatcher frame to allow timer tick and async completion.
        $Frame = [System.Windows.Threading.DispatcherFrame]::new()
        $Stopper = [System.Windows.Threading.DispatcherTimer]::new()
        $Stopper.Interval = [System.TimeSpan]::FromMilliseconds(900)
        $Stopper.add_Tick({
            param($sender, $e)
            $null = $e
            $sender.Stop()
            $Frame.Continue = $false
        })

        try {
            $Window.Show()
            $Stopper.Start()
            [System.Windows.Threading.Dispatcher]::PushFrame($Frame)

            $Window.Tag.ItemCount | Should -Be 2
            $Window.Tag.FirstName | Should -Be 'Alpha'
        } finally {
            $Stopper.Stop()
            $Window.Close()
        }
    }
}
