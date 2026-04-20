<#
.SYNOPSIS
    Creates a WPF Window object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.window
#>
function New-WPFWindow {
    [OutputType([System.Windows.Window])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    $WPFObject = [System.Windows.Window] @{
        Name = $Name
    }

    return $WPFObject
}
