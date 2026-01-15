<#
.SYNOPSIS
    Creates a WPF StackPanel object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.stackpanel
#>
function New-WPFStackPanel {
    [Alias('StackPanel')]
    [OutputType([System.Windows.Controls.StackPanel])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    try {
        $WPFObject = [System.Windows.Controls.StackPanel] @{
            Name = $Name
        }
        Register-WPFObject $Name $WPFObject
        Add-WPFType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (StackPanel) with error: $_"
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Update-WPFObject $WPFObject $ScriptBlock
    return $WPFObject
}
