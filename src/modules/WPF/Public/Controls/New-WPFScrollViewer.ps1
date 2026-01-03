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
            HorizontalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Visible
            VerticalScrollBarVisibility = [System.Windows.Controls.ScrollBarVisibility]::Visible
        }
        Register-WPFObject $Name $WPFObject
        Update-WPFObject $WPFObject $ScriptBlock
        Set-WPFObjectType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (ScrollViewer) with error: $_"
    }
    return $WPFObject
}
