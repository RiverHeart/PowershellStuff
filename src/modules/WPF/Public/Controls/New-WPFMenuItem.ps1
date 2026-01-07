<#
.SYNOPSIS
    Creates a WPF MenuItem object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.menuitem
#>
function New-WPFMenuItem {
    [Alias('MenuItem')]
    [OutputType([System.Windows.Controls.MenuItem])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    try {
        $WPFObject = [System.Windows.Controls.MenuItem] @{
            Name = $Name
            Header = $Name
        }
        Register-WPFObject $Name $WPFObject
        Update-WPFObject $WPFObject $ScriptBlock
        Add-WPFType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (MenuItem) with error: $_"
    }
    return $WPFObject
}
