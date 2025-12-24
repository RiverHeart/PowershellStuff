function Unregister-WPFObject {
    [CmdletBinding()]
    [Alias('Unregister')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    $KeyExists = $Script:WPFControlTable.ContainsKey($Name)
    if ($KeyExists) {
        Write-Debug "Unregistering object named '$Name'"
        $Script:WPFControlTable.Remove($Name)
    }
}
