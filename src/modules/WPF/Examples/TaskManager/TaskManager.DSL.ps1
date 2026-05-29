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
        SelectedProcess = $null
        TotalCpuPercent = 0
        TotalMemoryPercent = 0
    }

    When Loaded {
        Write-Debug 'TaskManager loaded.'
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

                    BindProperty SelectedItem SelectedProcess -Source (Reference 'Window').Tag -ScriptBlock {
                        $this.Mode = [System.Windows.Data.BindingMode]::TwoWay
                    }

                    When Sorting {
                        param($sender, $event)

                        # If the column hasn't been sorted yet, default to descending sort to show highest values at the top.
                        if ($event.Column.SortDirection -eq $null) {
                            $event.Column.SortDirection = 'Ascending'
                            # Allow default handler to toggle it to descending so sorting still happens.
                        }
                    }

                    When SelectionChanged {
                        Invoke-TaskManagerRefreshStopProcessCommand
                    }

                    $ProcessItems = [ObservableCollection[object]]::new()
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

                    Set-TaskManagerTotals `
                        -TotalCpuPercent $InitialTotalCpu `
                        -TotalMemoryPercent $InitialTotalMemoryPercent `
                        -UsedPhysicalMemoryMB $UsedPhysicalMemoryMB `
                        -TotalVisibleMemoryMB $TotalVisibleMemoryMB `
                        -TotalProcessMemoryMB $InitialTotalProcessMemory `
                        -Phase initial

                    $LastSampleTime = Get-Date

                    # Run background process sampling async to keep UI responsive
                    TimedEvent 'ProcessRefresh' 3000 {
                        Work {
                            # Background thread: expensive operation
                            $processData = Get-Process | ForEach-Object {
                                @{
                                    Name = $_.ProcessName
                                    Id = $_.Id
                                    CpuTime = [double] $_.TotalProcessorTime.TotalSeconds
                                    Memory = $_.WorkingSet64
                                }
                            }

                            $osMemory = Get-CimInstance -ClassName Win32_OperatingSystem
                            $totalVisibleMemoryMB = [double]([Math]::Max(1, [double]$osMemory.TotalVisibleMemorySize / 1KB))
                            $usedPhysicalMemoryMB = [double]([Math]::Max(0, $totalVisibleMemoryMB - ([double]$osMemory.FreePhysicalMemory / 1KB)))

                            [pscustomobject] @{
                                ProcessData = $processData
                                TotalVisibleMemoryMB = $totalVisibleMemoryMB
                                UsedPhysicalMemoryMB = $usedPhysicalMemoryMB
                            }
                        }

                        OnComplete {
                            param($RefreshData, $TimerSender)
                            # UI thread: update controls with results
                            if ($null -eq $RefreshData) { return }
                            if ($null -eq $TimerSender) { return }

                            $ProcessData = $RefreshData.ProcessData
                            if ($null -eq $ProcessData) { return }

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
                            $TotalProcessMemory = (
                                  $ProcessItems | Measure-Object -Property MemoryMB -Sum).Sum
                                  # Keep memory percent based on OS-wide used memory; process sum is debug-only due to shared-page double counting.
                                  $TotalVisibleMemoryMB = [double] $RefreshData.TotalVisibleMemoryMB
                                  $UsedPhysicalMemoryMB = [double] $RefreshData.UsedPhysicalMemoryMB
                                  $TotalMemoryPercent = [double]([Math]::Round(($UsedPhysicalMemoryMB / $TotalVisibleMemoryMB) * 100, 1)
                              )

                            Set-TaskManagerTotals `
                                -TotalCpuPercent $TotalCpu `
                                -TotalMemoryPercent $TotalMemoryPercent `
                                -UsedPhysicalMemoryMB $UsedPhysicalMemoryMB `
                                -TotalVisibleMemoryMB $TotalVisibleMemoryMB `
                                -TotalProcessMemoryMB $TotalProcessMemory `
                                -Phase refresh

                            # Restore selection
                            if ($null -ne $SelectedProcessId) {
                                $ReselectedItem = $ProcessItems | Where-Object { $_.Id -eq $SelectedProcessId } | Select-Object -First 1
                                if ($null -ne $ReselectedItem) {
                                    $ProcessList.SelectedItem = $ReselectedItem
                                }
                            }

                            $TimerState.LastSampleTime = $CurrentSampleTime
                        }
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
                        UseStyle 'TaskManager.StopButton'
                        [System.Windows.Controls.DockPanel]::SetDock($this, 'Right')
                        $this.Content = 'Stop Process'
                        Command 'StopProcessCommand' {
                            Execute {
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

                            CanExecute {
                                [bool] (Reference 'Window').Tag.SelectedProcess
                            }
                        }
                    }
                }
            }
        }
    }
} | Show-WPFWindow
