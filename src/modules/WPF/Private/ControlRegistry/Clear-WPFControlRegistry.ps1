function Clear-WPFControlRegistry {
    [CmdletBinding()]
    [OutputType([void])]
    param()

    Write-Debug "Clearing WPF Control Registry"
    $State = Get-WPFControlRegistry
    $State.Contexts = @{}
    $State.ActiveContextId = $null
}
