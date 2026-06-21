function New-WPFControlContext {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string] $Name,

        [string] $ContextId,

        [switch] $Activate
    )

    $State = Get-WPFControlRegistry
    $Id = if ($ContextId) { $ContextId } else { [guid]::NewGuid().ToString('N') }

    if (-not $State.Contexts.ContainsKey($Id)) {
        Write-Debug "Creating new WPF Control Context: Id='$Id', Name='$Name'"
        $State.Contexts[$Id] = [hashtable]::Synchronized(@{
            Id        = $Id
            Name      = $Name
            CreatedAt = [datetime]::UtcNow
            Objects   = [hashtable]::Synchronized(@{})
        })
    }

    if ($Activate) {
        Write-Debug "Activating WPF Control Context: Id='$Id'"
        $State.ActiveContextId = $Id
    }

    return $Id
}
