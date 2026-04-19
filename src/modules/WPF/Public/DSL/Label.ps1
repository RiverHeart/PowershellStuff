<#
.SYNOPSIS
    Creates a WPF Label object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.label
#>
function Label {
    [CmdletBinding()]
    [OutputType([void], [System.Windows.Controls.Label])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    try {
        $Label = [System.Windows.Controls.Label] @{
            Name = $Name
        }
        Register-WPFObject $Name $Label
        Add-WPFType $Label 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Label) with error: $_"
    }

    # Auto-attach self to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($Parent) {
        Write-Debug "Beginning auto-attach for $Name (Label)"
        Update-WPFObject $Parent $Label
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (Label)"
    Update-WPFObject $Label $ScriptBlock

    if ($this.Parent) { return }
    return $Label
}
