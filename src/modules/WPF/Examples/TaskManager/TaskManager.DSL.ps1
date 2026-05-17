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

    State @{
        # Add app state fields here.
        CurrentView = 'Home'
        IsDirty = $false
        TotalCpuPercent = 0
        TotalMemoryPercent = 0
    }

    When Loaded {
        Write-Debug 'TaskManager loaded.'
        Invoke-TaskManagerRefreshHeaderBindings -DataGrid (Reference 'ProcessList')
    }

    When Closed {
        Write-Debug 'TaskManager window closed.'
    }

    Grid 'Body' {
        # MARK: MENU
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

        # MARK: PROCESS LIST
        Row 'Expand' {
            Column {
                DataGrid 'ProcessList' {
                    $this = [System.Windows.Controls.DataGrid] $this
                    $this.AutoGenerateColumns = $false
                    $this.CanUserSortColumns = $true
                    $this.IsReadOnly = $true
                    $this.CanUserAddRows = $false
                    $this.CanUserDeleteRows = $false
                    $this.CanUserResizeRows = $false
                    $this.ColumnHeaderHeight = 60

                    When Sorting {
                        param($sender, $event)

                        # If the column hasn't been sorted yet, default to descending sort to show highest values at the top.
                        if ($event.Column.SortDirection -eq $null) {
                            $event.Column.SortDirection = 'Ascending'
                            # Allow default handler to toggle it to descending so sorting still happens.
                        }
                    }

                    $ProcessItems = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
                    $CpuSamples = @{}
                    $CpuCoreCount = [Math]::Max(1, [int]$env:NUMBER_OF_PROCESSORS)
                    # Use OS-level used physical memory for the header percent.
                    # Summing per-process WorkingSet64 can exceed RAM because shared pages are counted per process.
                    $OsMemory = Get-CimInstance -ClassName Win32_OperatingSystem
                    $TotalVisibleMemoryMB = [double]([Math]::Max(1, [double]$OsMemory.TotalVisibleMemorySize / 1KB))
                    $UsedPhysicalMemoryMB = [double]([Math]::Max(0, $TotalVisibleMemoryMB - ([double]$OsMemory.FreePhysicalMemory / 1KB)))
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

                    $InitialTotalCpu = ($ProcessItems | Measure-Object -Property CpuPercent -Sum).Sum
                    $InitialTotalProcessMemory = ($ProcessItems | Measure-Object -Property MemoryMB -Sum).Sum
                    $InitialTotalMemoryPercent = [double]([Math]::Round(($UsedPhysicalMemoryMB / $TotalVisibleMemoryMB) * 100, 1))

                    $Window = Reference 'Window'
                    $WindowState = if ($null -ne $Window.DataContext) {
                        Write-Debug 'TaskManager initial totals update target: Window.DataContext'
                        $Window.DataContext
                    } else {
                        Write-Debug 'TaskManager initial totals update target: Window.Tag (DataContext unavailable)'
                        $Window.Tag
                    }

                    $WindowState.TotalCpuPercent = $InitialTotalCpu
                    $WindowState.TotalMemoryPercent = $InitialTotalMemoryPercent
                    Write-Debug ("TaskManager initial totals set: CPU={0:N1}%, Memory={1:N1}% (Used={2:N1}MB/{3:N1}MB, ProcessSum={4:N1}MB)" -f [double]$InitialTotalCpu, [double]$InitialTotalMemoryPercent, [double]$UsedPhysicalMemoryMB, [double]$TotalVisibleMemoryMB, [double]$InitialTotalProcessMemory)

                    Invoke-TaskManagerRefreshHeaderBindings -DataGrid $this

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

                          # Calculate totals
                          $TotalCpu = ($ProcessItems | Measure-Object -Property CpuPercent -Sum).Sum
                          $TotalProcessMemory = ($ProcessItems | Measure-Object -Property MemoryMB -Sum).Sum
                          # Keep memory percent based on OS-wide used memory; process sum is debug-only due to shared-page double counting.
                          $OsMemory = Get-CimInstance -ClassName Win32_OperatingSystem
                          $TotalVisibleMemoryMB = [double]([Math]::Max(1, [double]$OsMemory.TotalVisibleMemorySize / 1KB))
                          $UsedPhysicalMemoryMB = [double]([Math]::Max(0, $TotalVisibleMemoryMB - ([double]$OsMemory.FreePhysicalMemory / 1KB)))
                          $TotalMemoryPercent = [double]([Math]::Round(($UsedPhysicalMemoryMB / $TotalVisibleMemoryMB) * 100, 1))

                          # Update window state with totals
                          $Window = Reference 'Window'
                          $WindowState = if ($null -ne $Window.DataContext) {
                              Write-Debug 'TaskManager totals update target: Window.DataContext'
                              $Window.DataContext
                          } else {
                              Write-Debug 'TaskManager totals update target: Window.Tag (DataContext unavailable)'
                              $Window.Tag
                          }

                          $WindowState.TotalCpuPercent = $TotalCpu
                          $WindowState.TotalMemoryPercent = $TotalMemoryPercent
                          Write-Debug ("TaskManager totals updated: CPU={0:N1}%, Memory={1:N1}% (Used={2:N1}MB/{3:N1}MB, ProcessSum={4:N1}MB), Items={5}" -f [double]$TotalCpu, [double]$TotalMemoryPercent, [double]$UsedPhysicalMemoryMB, [double]$TotalVisibleMemoryMB, [double]$TotalProcessMemory, $ProcessItems.Count)

                          Invoke-TaskManagerRefreshHeaderBindings -DataGrid $ProcessList

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

                    DataGridTextColumn 'Name' 'Name' {
                        $this.Width = [DataGridLength]::new(3, [DataGridLengthUnitType]::Star)
                    }

                    DataGridTextColumn 'ID' 'Id' {
                        $this.Width = [DataGridLength]::new(1, [DataGridLengthUnitType]::Star)
                    }

                    DataGridTextColumn 'CPU' (Binding 'CpuPercent' -ScriptBlock {
                        $this.Converter = New-WPFValueConverter {
                            param($Value)
                            if ($null -eq $Value) { return '' }
                            return ('{0:N1}%' -f [double]$Value)
                        }
                    }) {
                        $this.Width = [DataGridLength]::new(1, [DataGridLengthUnitType]::Star)
                        UseStyle 'RightAlignedDataGridHeader' $this -TargetType HeaderStyle
                        UseStyle 'RightAlignedDataGridCell' $this -TargetType ElementStyle
                        $this.HeaderTemplate = (New-ColumnHeaderTemplate -TotalPropertyPath 'TotalCpuPercent' -Label 'CPU' -ValueConverter {
                            param($Value)
                            if ($null -eq $Value) { '0.0%' } else { '{0:N1}%' -f [double]$Value }
                        })
                    }

                    DataGridTextColumn 'Memory' (Binding 'MemoryMB' -ScriptBlock {
                        $this.Converter = New-WPFValueConverter {
                            param($Value)
                            if ($null -eq $Value) { return '' }
                            return ('{0:N1} MB' -f [double]$Value)
                        }
                    }) {
                        $this.Width = [DataGridLength]::new(1, [DataGridLengthUnitType]::Star)
                        UseStyle 'RightAlignedDataGridHeader' $this -TargetType HeaderStyle
                        UseStyle 'RightAlignedDataGridCell' $this -TargetType ElementStyle
                        $this.HeaderTemplate = (New-ColumnHeaderTemplate -TotalPropertyPath 'TotalMemoryPercent' -Label 'Memory' -ValueConverter {
                            param($Value)
                            if ($null -eq $Value) { '0.0%' } else { '{0:N1}%' -f [double]$Value }
                        })
                    }

                    $Window = Reference 'Window'
                    $WindowState = if ($null -ne $Window.DataContext) {
                        $Window.DataContext
                    } else {
                        $Window.Tag
                    }

                    if ($null -ne $WindowState.PSObject.Methods['AddBinding']) {
                        $WindowState.AddBinding('TotalCpuPercent', {
                                param($Value)
                                Write-Debug ("TaskManager TotalCpuPercent changed: {0}" -f $Value)
                                Invoke-TaskManagerRefreshHeaderBindings -DataGrid (Reference 'ProcessList')
                            }, $false)

                        $WindowState.AddBinding('TotalMemoryPercent', {
                                param($Value)
                            Write-Debug ("TaskManager TotalMemoryPercent changed: {0}" -f $Value)
                                Invoke-TaskManagerRefreshHeaderBindings -DataGrid (Reference 'ProcessList')
                            }, $false)
                    }
                }
            }
        }

        # MARK: BOTTOM BAR
        Row {
            Column 'Expand' {
                DockPanel 'BottomBar' {
                    $this = [System.Windows.Controls.DockPanel] $this
                    $this.LastChildFill = $false
                    $this.Margin = 8, 6
                    Label "ProcessCountLabel" {
                        $this.Content = "Processes: "
                        $this.FontWeight = 'Bold'
                        $this.VerticalAlignment = 'Center'
                        $this.Margin = 0, 0, 4, 0
                    }
                    TextBlock 'ProcessCount' {
                        $this.VerticalAlignment = 'Center'
                        $this.Margin = 0, 0, 12, 0
                        BindProperty Text ItemsSource.Count -Source (Reference 'ProcessList')
                    }
                    Button 'StopProcessButton' {
                        [System.Windows.Controls.DockPanel]::SetDock($this, 'Right')
                        $this.Content = 'Stop Process'
                        $this.Margin = 0, 10, 10, 10
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
