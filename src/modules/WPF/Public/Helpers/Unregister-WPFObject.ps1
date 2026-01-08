function Unregister-WPFObject {
    [CmdletBinding()]
    [Alias('Unregister')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({ Complete-RegisteredObject @args })]
        [string[]] $Name
    )

    if (-not $Name) {
        Write-Debug "Unregistering all objects (total $($Script:WPFControlTable.Count))."
        $Script:WPFControlTable = @{}
    }

    $KeyExists = $Script:WPFControlTable.ContainsKey($Name)
    if ($KeyExists) {
        Write-Debug "Unregistering object named '$Name'"
        $Script:WPFControlTable.Remove($Name)
    }
}
