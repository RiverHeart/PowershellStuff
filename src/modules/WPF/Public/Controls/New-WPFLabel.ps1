<#
.SYNOPSIS
    Creates a WPF Label object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.label
#>
function New-WPFLabel {
    [Alias('Label')]
    [OutputType([System.Windows.Controls.Label])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    try {
        $WPFObject = [System.Windows.Controls.Label] @{
            Name = $Name
        }
        Register-WPFObject $Name $WPFObject
        Add-WPFType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Label) with error: $_"
    }

    if ($ScriptBlock) {
        # NOTE: Allow exceptions from child objects to bubble up
        Update-WPFObject $WPFObject $ScriptBlock
    }

    return $WPFObject
}
