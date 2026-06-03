function Clear-WPFControlRegistry {
    [CmdletBinding()]
    [OutputType([void])]
    param()

    Write-Debug "Clearing WPF Control Registry"
    $State = Get-WPFControlRegistry

    # Dispose all IDisposable objects before clearing the registry
    # Snapshot keys up front because disposing objects can indirectly mutate
    # registry tables (for example via events) while we are clearing.
    foreach ($ContextId in @($State.Contexts.Keys)) {
        if (-not $State.Contexts.ContainsKey($ContextId)) {
            continue
        }

        $Context = $State.Contexts[$ContextId]
        foreach ($ObjectName in @($Context.Objects.Keys)) {
            if (-not $Context.Objects.ContainsKey($ObjectName)) {
                continue
            }

            $Object = $Context.Objects[$ObjectName]

            if ($Object -is [System.Windows.Threading.DispatcherTimer]) {
                # Timers can outlive the window that created them unless we stop them
                # explicitly before dropping the registry context. That showed up as one
                # app's TimedEvent continuing to tick after close and then failing inside
                # a later app because its referenced controls no longer existed.
                try {
                    $Object.Stop()

                    if ($Object.Tag -is [hashtable]) {
                        $PendingPowerShell = $Object.Tag.PendingPowerShell
                        $PendingRunspace = $Object.Tag.PendingRunspace

                        if ($null -ne $PendingPowerShell) {
                            try {
                                $PendingPowerShell.Stop()
                            } catch {
                            }

                            $PendingPowerShell.Dispose()
                        }

                        if ($null -ne $PendingRunspace) {
                            try {
                                $PendingRunspace.Close()
                            } catch {
                            }

                            $PendingRunspace.Dispose()
                        }

                        $Object.Tag.PendingPowerShell = $null
                        $Object.Tag.PendingRunspace = $null
                        $Object.Tag.PendingAsyncResult = $null
                        $Object.Tag.PendingOutput = $null
                        $Object.Tag.IsRefreshing = $false
                    }
                } catch {
                    Write-Warning "Failed to stop timer '$ObjectName' from context '$ContextId': $_"
                }
            }

            if ($Object -is [System.IDisposable]) {
                try {
                    Write-Debug "Disposing object '$ObjectName' from context '$ContextId'"
                    $Object.Dispose()
                } catch {
                    Write-Warning "Failed to dispose object '$ObjectName' from context '$ContextId': $_"
                }
            }
        }
    }

    $State.Contexts = @{}
    $State.ActiveContextId = $null
}
