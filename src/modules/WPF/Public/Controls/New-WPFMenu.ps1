<#
.SYNOPSIS
    Creates a WPF Menu object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.menu
#>
function New-WPFMenu {
    [Alias('Menu')]
    [OutputType([System.Windows.Controls.Menu])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    try {
        $WPFObject = [System.Windows.Controls.Menu] @{
            Name = $Name
        }
        Register-WPFObject $Name $WPFObject
        Update-WPFObject $WPFObject $ScriptBlock
        Set-WPFObjectType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Menu) with error: $_"
    }
    return $WPFObject
}
