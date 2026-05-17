function Remove-WPFControlContext {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [string] $ContextId,

        [object] $InputObject
    )

    $State = Get-WPFControlRegistry
    $Id = Resolve-WPFControlContextId -ContextId $ContextId -InputObject $InputObject
    if (-not $Id) {
        return
    }

    $Context = $State.Contexts[$Id]
    if ($null -ne $Context) {
        foreach ($ObjectName in @($Context.Objects.Keys)) {
            $Object = $Context.Objects[$ObjectName]

            if ($Object -is [System.Windows.Threading.DispatcherTimer]) {
                # Context removal has to stop timers before the context disappears.
                # If we only remove the registry entries, any active DispatcherTimer can
                # keep firing and run async completion against a dead UI/control context.
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
                    Write-Warning "Failed to stop timer '$ObjectName' from context '$Id': $_"
                }
            }

            if ($Object -is [System.IDisposable]) {
                try {
                    $Object.Dispose()
                } catch {
                    Write-Warning "Failed to dispose object '$ObjectName' from context '$Id': $_"
                }
            }
        }
    }

    [void] $State.Contexts.Remove($Id)

    if ($State.ActiveContextId -eq $Id) {
        if ($State.Contexts.Count -gt 0) {
            $State.ActiveContextId = @($State.Contexts.Keys)[0]
        } else {
            $State.ActiveContextId = $null
        }
    }
}
