<#
.SYNOPSIS
    Creates a WPF ScrollViewer object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.scrollviewer
#>
function New-WPFScrollViewer {
    [Alias('ScrollViewer')]
    [OutputType([System.Windows.Controls.ScrollViewer])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    try {
        $WPFObject = [System.Windows.Controls.ScrollViewer] @{
            Name = $Name
        }
        Register-WPFObject $Name $WPFObject
        Add-WPFType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (ScrollViewer) with error: $_"
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Update-WPFObject $WPFObject $ScriptBlock
    return $WPFObject
}
