function Unregister-WPFObject {
    [CmdletBinding()]
    [Alias('Unregister')]
    param(
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({ Complete-WPFRegisteredObject @args })]
        [string[]] $Name,

        [string] $ContextId
    )

    $State = Get-WPFControlRegistry

    if (-not $Name) {
        if ($ContextId) {
            if ($State.Contexts.ContainsKey($ContextId)) {
                $Count = $State.Contexts[$ContextId].Objects.Count
                Write-Debug "Unregistering all objects from context '$ContextId' (total $Count)."
                $State.Contexts[$ContextId].Objects = @{}
            }
            return
        }

        Write-Debug 'Unregistering all objects from all contexts.'
        Clear-WPFControlRegistry
        return
    }

    foreach ($Item in $Name) {
        $Removed = $false

        if ($ContextId) {
            if ($State.Contexts.ContainsKey($ContextId) -and $State.Contexts[$ContextId].Objects.ContainsKey($Item)) {
                Write-Debug "Unregistering object named '$Item' from context '$ContextId'"
                [void] $State.Contexts[$ContextId].Objects.Remove($Item)
                $Removed = $true
            }
        } else {
            foreach ($Context in $State.Contexts.Values) {
                if ($Context.Objects.ContainsKey($Item)) {
                    Write-Debug "Unregistering object named '$Item' from context '$($Context.Id)'"
                    [void] $Context.Objects.Remove($Item)
                    $Removed = $true
                }
            }
        }

        if (-not $Removed) {
            Write-Warning "No object named '$Item' was registered."
        }
    }
}
