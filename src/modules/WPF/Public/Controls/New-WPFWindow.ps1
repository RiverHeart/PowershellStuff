<#
.SYNOPSIS
    Creates a WPF Window object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.window
#>
function New-WPFWindow {
    [Alias('Window')]
    [OutputType([System.Windows.Window])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    try {
        $WPFObject = [System.Windows.Window] @{
            Name = $Name
        }
        Register-WPFObject $Name $WPFObject
        Update-WPFObject $WPFObject $ScriptBlock
        if (-not $WPFObject.Height -and -not $WPFObject.Width){
            $WPFObject.SizeToContent = 'WidthAndHeight'
        }
        Add-WPFType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Window) with error: $_"
    }
    return $WPFObject
}
