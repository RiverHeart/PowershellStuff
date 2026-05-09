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
    $this.Title = 'TaskManager'
    $this.WindowStartupLocation = [WindowStartupLocation]::CenterScreen
    $this.Width = 1000
    $this.Height = 700
    $this.Tag = New-WPFObservableState @{
        # Add app state fields here.
        CurrentView = 'Home'
        IsDirty = $false
        ProcessUpdateTimer = $null
    }

    When Loaded {
        Write-Debug 'TaskManager loaded.'
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
                    # TimedEvent 2000 {
                    #     $this.ItemsSource = Get-Process
                    # }

                    $ProcessItems = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
                    $CpuSamples = @{}
                    $CpuCoreCount = [Math]::Max(1, [int]$env:NUMBER_OF_PROCESSORS)
                    $LastSampleTime = Get-Date

                    $UpdateProcessItems = {
                        param(
                            [System.Collections.ObjectModel.ObservableCollection[object]] $Items,
                            [hashtable] $Samples,
                            [datetime] $PreviousSampleTime,
                            [int] $CoreCount
                        )

                        $CurrentSampleTime = Get-Date
                        $ElapsedSeconds = [Math]::Max(0.001, ($CurrentSampleTime - $PreviousSampleTime).TotalSeconds)
                        $CurrentProcesses = Get-Process

                        $Items.Clear()
                        foreach ($Process in $CurrentProcesses) {
                            $CurrentCpu = [double]$Process.TotalProcessorTime.TotalSeconds
                            $PreviousCpu = $null
                            if ($Samples.ContainsKey($Process.Id)) {
                                $PreviousCpu = [double]$Samples[$Process.Id]
                            }

                            $CpuPercent =
                                if ($null -ne $PreviousCpu) {
                                    [double]([Math]::Round([Math]::Max(0, (($CurrentCpu - $PreviousCpu) / $ElapsedSeconds) * 100 / $CoreCount), 1))
                                } else {
                                    [double]0
                                }

                            $Items.Add([pscustomobject]@{
                                Name = $Process.ProcessName
                                Id = $Process.Id
                                CpuPercent = $CpuPercent
                                MemoryMB = [Math]::Round([double]$Process.WorkingSet64 / 1MB, 1)
                            })

                            $Samples[$Process.Id] = $CurrentCpu
                        }

                        foreach ($SampledPid in @($Samples.Keys)) {
                            if (-not ($CurrentProcesses.Id -contains $SampledPid)) {
                                $Samples.Remove($SampledPid)
                            }
                        }

                        return $CurrentSampleTime
                    }

                    $LastSampleTime = & $UpdateProcessItems $ProcessItems $CpuSamples $LastSampleTime $CpuCoreCount
                    $this.ItemsSource = $ProcessItems

                    $Timer = [DispatcherTimer]::new()
                    $Timer.Interval = [TimeSpan]::FromSeconds(3)
                    $Timer.add_Tick({
                        $TimerState = $this.Tag
                        $TimerState.LastSampleTime = & $TimerState.UpdateProcessItems `
                            $TimerState.Items `
                            $TimerState.CpuSamples `
                            $TimerState.LastSampleTime `
                            $TimerState.CpuCoreCount
                    })
                    (Reference 'Window').Tag.ProcessUpdateTimer = $Timer
                    $Timer.Tag = @{
                        Items = $ProcessItems
                        CpuSamples = $CpuSamples
                        CpuCoreCount = $CpuCoreCount
                        LastSampleTime = $LastSampleTime
                        UpdateProcessItems = $UpdateProcessItems
                    }
                    $Timer.Start()

                    $this.AutoGenerateColumns = $false
                    $this.CanUserSortColumns = $true
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
    }
} | Show-WPFWindow
