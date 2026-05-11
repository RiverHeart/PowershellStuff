using namespace System.Collections.ObjectModel
using namespace System.Windows
using namespace System.Windows.Controls
using namespace System.Windows.Input
using namespace System.Windows.Threading

<#
.SYNOPSIS
    Entry point for the TaskManager WPF DSL project.
#>

# Change to the script directory if we're not in it.
if ($PSScriptRoot -and $PWD -ne $PSScriptRoot) {
    Set-Location $PSScriptRoot
}

Import-Module ../../ -ErrorAction Stop -Force

Import "$PSScriptRoot/TaskManager.Styles.ps1"
Import "$PSScriptRoot/functions"

Window 'Window' {
    $this = [System.Windows.Window]$this
    $this.Title = 'TaskManager'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.Width = 1000
    $this.Height = 700
    $this.Tag = New-WPFObservableState @{
        # Add app state fields here.
        CurrentView = 'Home'
        IsDirty = $false
    }

    When Loaded {
        Write-Debug 'TaskManager loaded.'
    }

    When Closed {
        Write-Debug 'TaskManager window closed.'
    }

    # Uncomment this block to add window-wide keyboard shortcuts.
    # When KeyDown {
    #     param($sender, $event)
    #
    #     switch ($event.Key) {
    #         'Escape' {
    #             (Reference 'Window').Close()
    #             $event.Handled = $true
    #         }
    #     }
    # }

    Grid 'Body' {
        Row {
            Column 'Expand' {
                MenuBar 'Menu' {
                    MenuItem '(F)ile/(E)xit' {
                        Command 'CloseCommand' 'Ctrl+q' {
                            Write-Debug "Close command triggered. Closing window."
                            (Reference 'Window').Close()
                        }
                    }
                }
            }
        }

        Row 'Expand' {
            Column {
                DataGrid 'ProcessList' {
                    $this.AutoGenerateColumns = $false
                    $this.CanUserSortColumns = $true
                    $this.IsReadOnly = $true
                    $this.CanUserAddRows = $false
                    $this.CanUserDeleteRows = $false
                    $this.CanUserResizeRows = $false
                    $this.VerticalScrollBarVisibility = [ScrollBarVisibility]::Auto
                    $this.HorizontalScrollBarVisibility = [ScrollBarVisibility]::Auto

                    $this = [System.Windows.Controls.DataGrid] $this
                    $ProcessItems = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
                    $CpuSamples = @{}
                    $CpuCoreCount = [Math]::Max(1, [int]$env:NUMBER_OF_PROCESSORS)
                    $LastSampleTime = Get-Date

                    $this.ItemsSource = $ProcessItems

                    # Prime the grid immediately so it is populated before the first timed refresh.
                    $InitialProcessData = Get-Process | ForEach-Object {
                        @{
                            Name = $_.ProcessName
                            Id = $_.Id
                            CpuTime = [double] $_.TotalProcessorTime.TotalSeconds
                            Memory = $_.WorkingSet64
                        }
                    }

                    foreach ($Process in $InitialProcessData) {
                        $ProcessItems.Add([pscustomobject] @{
                            Name = $Process.Name
                            Id = $Process.Id
                            CpuPercent = [double] 0
                            MemoryMB = [Math]::Round([double] $Process.Memory / 1MB, 1)
                        })

                        $CpuSamples[$Process.Id] = [double] $Process.CpuTime
                    }

                    $LastSampleTime = Get-Date

                    # Run background process sampling async to keep UI responsive
                    TimedEvent 'ProcessRefresh' 3000 `
                      -Work {
                          # Background thread: expensive operation
                          Get-Process | ForEach-Object {
                              @{
                                  Name = $_.ProcessName
                                  Id = $_.Id
                                  CpuTime = [double] $_.TotalProcessorTime.TotalSeconds
                                  Memory = $_.WorkingSet64
                              }
                          }
                      } `
                      -OnComplete {
                          param($ProcessData, $TimerSender)
                          # UI thread: update controls with results
                          if ($null -eq $ProcessData) { return }
                          if ($null -eq $TimerSender) { return }

                          $TimerState = $TimerSender.Tag
                          if ($null -eq $TimerState) { return }

                          $CurrentSampleTime = Get-Date
                          $ElapsedSeconds = [Math]::Max(0.001, ($CurrentSampleTime - $TimerState.LastSampleTime).TotalSeconds)
                          $CoreCount = $TimerState.CpuCoreCount
                          $CpuSamples = $TimerState.CpuSamples
                          $ProcessItems = $TimerState.Items

                          # Preserve selection
                          $ProcessList = Reference 'ProcessList'
                          $SelectedProcess = $ProcessList.SelectedItem
                          $SelectedProcessId = if ($null -ne $SelectedProcess) { $SelectedProcess.Id } else { $null }

                          $ProcessItems.Clear()
                          foreach ($Process in $ProcessData) {
                              $CurrentCpu = [double] $Process.CpuTime
                              $PreviousCpu = $null
                              if ($CpuSamples.ContainsKey($Process.Id)) {
                                  $PreviousCpu = [double] $CpuSamples[$Process.Id]
                              }

                              $CpuPercent = if ($null -ne $PreviousCpu) {
                                  [double] ([Math]::Round([Math]::Max(0, (($CurrentCpu - $PreviousCpu) / $ElapsedSeconds) * 100 / $CoreCount), 1))
                              } else {
                                  [double] 0
                              }

                              $ProcessItems.Add([pscustomobject] @{
                                  Name = $Process.Name
                                  Id = $Process.Id
                                  CpuPercent = $CpuPercent
                                  MemoryMB = [Math]::Round([double] $Process.Memory / 1MB, 1)
                              })

                              $CpuSamples[$Process.Id] = $CurrentCpu
                          }

                          # Clean up old samples
                          $ActiveProcessIds = $ProcessData | ForEach-Object { $_.Id }
                          foreach ($SampledPid in @($CpuSamples.Keys)) {
                              if (-not ($ActiveProcessIds -contains $SampledPid)) {
                                  $CpuSamples.Remove($SampledPid)
                              }
                          }

                          # Restore selection
                          if ($null -ne $SelectedProcessId) {
                              $ReselectedItem = $ProcessItems | Where-Object { $_.Id -eq $SelectedProcessId } | Select-Object -First 1
                              if ($null -ne $ReselectedItem) {
                                  $ProcessList.SelectedItem = $ReselectedItem
                              }
                          }

                          $TimerState.LastSampleTime = $CurrentSampleTime
                      }

                    $ProcessRefreshTimer = Reference 'ProcessRefresh'
                    $ProcessRefreshTimer.Tag = @{
                        Items = $ProcessItems
                        CpuSamples = $CpuSamples
                        CpuCoreCount = $CpuCoreCount
                        LastSampleTime = $LastSampleTime
                    }

                    $this.Columns.Add([DataGridTextColumn] @{
                        Header  = 'Name'
                        Width   = [DataGridLength]::new(3, [DataGridLengthUnitType]::Star)
                        Binding = [System.Windows.Data.Binding] 'Name'
                    })
                    $this.Columns.Add([DataGridTextColumn] @{
                        Header  = 'ID'
                        Width   = [DataGridLength]::new(1, [DataGridLengthUnitType]::Star)
                        Binding = [System.Windows.Data.Binding] 'Id'
                    })
                    $this.Columns.Add([DataGridTextColumn] @{
                        Header  = 'CPU'
                        Width   = [DataGridLength]::new(1, [DataGridLengthUnitType]::Star)
                        Binding = (Binding 'CpuPercent' -ScriptBlock {
                            $this.Converter = New-WPFValueConverter {
                                param($Value)
                                if ($null -eq $Value) { return '' }
                                return ('{0:N1}%' -f [double]$Value)
                            }
                        })
                    })
                    $this.Columns.Add([DataGridTextColumn] @{
                        Header  = 'Memory (MB)'
                        Width   = [DataGridLength]::new(1, [DataGridLengthUnitType]::Star)
                        Binding = (Binding 'MemoryMB' -ScriptBlock {
                            $this.Converter = New-WPFValueConverter {
                                param($Value)
                                if ($null -eq $Value) { return '' }
                                return ('{0:N1}' -f [double]$Value)
                            }
                        })
                    })
                }
            }
        }

        Row {
            Column 'Expand' {
                DockPanel 'BottomBar' {
                    Label "ProcessCountLabel" {
                        $this.Content = "Processes: "
                        $this.FontWeight = 'Bold'
                    }
                    TextBlock 'ProcessCount' {
                        $this.Text = (Binding 'Items.Count' -Source (Reference 'ProcessList'))
                    }
                    Button 'StopProcessButton' {
                        $this.Content = 'Stop Selected Process'
                        $this.Margin = 10, 0, 0, 0
                        Command 'StopProcessCommand' {
                            param($sender, $event)
                            $SelectedProcess = (Reference 'ProcessList').SelectedItem
                            if ($null -ne $SelectedProcess) {
                                try {
                                    Stop-Process -Id $SelectedProcess.Id -ErrorAction Stop
                                } catch {
                                    [System.Windows.MessageBox]::Show("Failed to stop process: $_", "Error", [MessageBoxButton]::OK, [MessageBoxImage]::Error)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
} | Show-WPFWindow
