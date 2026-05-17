<#
.SYNOPSIS
    Keyword for creating and registering a DispatcherTimer that runs a scriptblock periodically.

.DESCRIPTION
    Creates a DispatcherTimer with the specified interval and scriptblock. The timer is
    automatically registered in the control registry for automatic cleanup and disposal
    when the window closes.

    Two usage modes are supported:

    SYNC MODE (Scriptblock on UI thread):
    The scriptblock receives ($sender, $e) parameters where $sender is the DispatcherTimer.
    Runs directly on the UI thread.

    ASYNC MODE (Background work with UI result handler):
    The -Work scriptblock runs in a background runspace and should return data.
    The -OnComplete scriptblock runs on the UI thread and receives the work result as a parameter.
    An implicit IsRefreshing guard prevents overlapping work execution.

.PARAMETER Name
    The name to register the timer under. Used for reference and in control registry.

.PARAMETER IntervalMilliseconds
    The interval in milliseconds between timer ticks.

.PARAMETER ScriptBlock
    (Sync mode) The scriptblock to execute on each timer tick on the UI thread.
    Incompatible with -Work and -OnComplete.

.PARAMETER Work
    (Async mode) A scriptblock that performs background work and returns data.
    Must be used together with -OnComplete. The scriptblock runs on a background thread.

.PARAMETER OnComplete
    (Async mode) A scriptblock that handles the result of -Work on the UI thread.
    Receives the work result as a single parameter. Must be used together with -Work.

.EXAMPLE
    Sync mode (UI thread):
    Window 'MainWindow' {
        TimedEvent 'RefreshUI' 3000 {
            param($sender, $e)
            $this.Title = "Updated: $(Get-Date)"
        }
    }

.EXAMPLE
    Async mode (background work, UI-safe update):
    Window 'MainWindow' {
        TimedEvent 'RefreshData' 3000 `
          -Work {
              # Runs on background thread, can be slow
              [System.Diagnostics.Process]::GetProcesses()
          } `
          -OnComplete {
              param($Processes)
              # Runs on UI thread, safe to update controls
              $ProcessList.Clear()
              foreach ($p in $Processes) { $ProcessList.Add($p) }
          }
    }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.threading.dispatchertimer
#>
function TimedEvent {
    [CmdletBinding(DefaultParameterSetName='Sync')]
    [Alias('-TimedEvent')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\w+$')]
        [string] $Name,

        [Parameter(Mandatory, Position=1)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $IntervalMilliseconds,

        [Parameter(Mandatory, Position=2, ParameterSetName='Sync')]
        [scriptblock] $ScriptBlock,

        [Parameter(Mandatory, ParameterSetName='Async')]
        [scriptblock] $Work,

        [Parameter(Mandatory, ParameterSetName='Async')]
        [scriptblock] $OnComplete
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

    Write-Debug "Creating TimedEvent '$Name' with interval ${IntervalMilliseconds}ms"

    try {
        # Create the timer
        $Timer = [System.Windows.Threading.DispatcherTimer]::new()
        $Timer.Interval = [System.TimeSpan]::FromMilliseconds($IntervalMilliseconds)

        # SYNC MODE: Direct scriptblock on UI thread
        if ($PSCmdlet.ParameterSetName -eq 'Sync') {
            Write-Debug "  Using sync mode (UI thread execution)"

            $TickHandler = $ScriptBlock

            # Add the tick handler with proper parameter passing
            $Timer.add_Tick({
                param($sender, $e)
                & $TickHandler $sender $e
            }.GetNewClosure())
        }
        # ASYNC MODE: Background work + UI-thread result handler
        else {
            Write-Debug "  Using async mode (background work with UI-thread result)"

            # Initialize the IsRefreshing guard in the timer's Tag
            $Timer.Tag = @{
                IsRefreshing = $false
                PendingPowerShell = $null
                PendingRunspace = $null
                PendingAsyncResult = $null
                PendingOutput = $null
                CompletionCount = 0
            }

            $WorkScript = $Work
            $CompleteScript = $OnComplete

            # Create the async tick handler
            $TickHandler = {
                param($sender, $e)

                # Skip if already refreshing (IsRefreshing guard)
                if ($sender.Tag.IsRefreshing) {
                    $PendingResult = $sender.Tag.PendingAsyncResult
                    if ($null -eq $PendingResult) {
                        Write-Debug "  Skipping tick: already refreshing"
                        return
                    }

                    if (-not $PendingResult.IsCompleted) {
                        Write-Debug "  Skipping tick: work still running"
                        return
                    }

                    Write-Debug "  Completing async work for TimedEvent '$Name'"

                    $PendingPowerShell = $sender.Tag.PendingPowerShell
                    $PendingRunspace = $sender.Tag.PendingRunspace
                    $PendingOutput = $sender.Tag.PendingOutput

                    try {
                        $null = $PendingPowerShell.EndInvoke($PendingResult)
                        $WorkResult = @()
                        if ($null -ne $PendingOutput) {
                            # Materialize pipeline output items, not the output buffer object itself.
                            $WorkResult = @($PendingOutput | ForEach-Object { $_ })
                        }

                        $ErrorRecords = @()
                        if ($null -ne $PendingPowerShell.Streams -and $null -ne $PendingPowerShell.Streams.Error) {
                            $ErrorRecords = @($PendingPowerShell.Streams.Error)
                        }

                        if ($PendingPowerShell.HadErrors -and $ErrorRecords.Length -gt 0) {
                            throw $ErrorRecords[0]
                        }

                        & $CompleteScript $WorkResult $sender
                        $sender.Tag.CompletionCount = [int] $sender.Tag.CompletionCount + 1
                    } catch {
                        Write-Error "TimedEvent '$Name' async completion failed: $_"
                    } finally {
                        if ($null -ne $PendingPowerShell) {
                            $PendingPowerShell.Dispose()
                        }

                        if ($null -ne $PendingRunspace) {
                            $PendingRunspace.Close()
                            $PendingRunspace.Dispose()
                        }

                        $sender.Tag.PendingPowerShell = $null
                        $sender.Tag.PendingRunspace = $null
                        $sender.Tag.PendingAsyncResult = $null
                        $sender.Tag.PendingOutput = $null
                        $sender.Tag.IsRefreshing = $false
                    }

                    return
                }

                # Set guard and start background work in a dedicated runspace.
                Write-Debug "  Starting async work for TimedEvent '$Name'"
                $sender.Tag.IsRefreshing = $true

                $WorkerPowerShell = $null
                $WorkerRunspace = $null

                try {
                    $WorkerRunspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
                    $WorkerRunspace.Open()

                    $WorkerPowerShell = [System.Management.Automation.PowerShell]::Create()
                    $WorkerPowerShell.Runspace = $WorkerRunspace

                    # Add script text directly to avoid async hangs from cross-runspace scriptblock variable invocation.
                    $null = $WorkerPowerShell.AddScript($WorkScript.ToString())

                    $InputBuffer = [System.Management.Automation.PSDataCollection[psobject]]::new()
                    $OutputBuffer = [System.Management.Automation.PSDataCollection[psobject]]::new()
                    $InputBuffer.Complete()

                    $sender.Tag.PendingRunspace = $WorkerRunspace
                    $sender.Tag.PendingPowerShell = $WorkerPowerShell
                    $sender.Tag.PendingOutput = $OutputBuffer
                    $sender.Tag.PendingAsyncResult = $WorkerPowerShell.BeginInvoke($InputBuffer, $OutputBuffer)
                } catch {
                    Write-Error "TimedEvent '$Name' failed to start async work: $_"

                    if ($null -ne $WorkerPowerShell) {
                        $WorkerPowerShell.Dispose()
                    }

                    if ($null -ne $WorkerRunspace) {
                        $WorkerRunspace.Close()
                        $WorkerRunspace.Dispose()
                    }

                    $sender.Tag.PendingPowerShell = $null
                    $sender.Tag.PendingRunspace = $null
                    $sender.Tag.PendingAsyncResult = $null
                    $sender.Tag.PendingOutput = $null
                    $sender.Tag.IsRefreshing = $false
                }
            }

            $Timer.add_Tick($TickHandler.GetNewClosure())
        }

        # Register in the same registry used by Reference and automatic cleanup.
        Register-WPFObject -Name $Name -InputObject $Timer -Overwrite
        Write-Debug "Registered TimedEvent '$Name' in control registry"

        # Start the timer
        $Timer.Start()
        Write-Debug "Started TimedEvent '$Name'"

        return
    } catch {
        Write-Error "Failed to create TimedEvent '$Name': $_"
    }
}
