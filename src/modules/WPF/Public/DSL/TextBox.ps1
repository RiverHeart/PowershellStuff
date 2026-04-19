<#
.SYNOPSIS
    Creates a WPF TextBox object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.textbox
#>
function TextBox {
    [CmdletBinding()]
    [OutputType([void], [System.Windows.Controls.TextBox])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    try {
        $TextBox = [System.Windows.Controls.TextBox] @{
            Name = $Name
        }
        Register-WPFObject $Name $TextBox
        Add-WPFType $TextBox 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (TextBox) with error: $_"
    }

    # Attach to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($Parent) {
        Write-Debug "Beginning auto-attach for $Name (TextBox)"
        Update-WPFObject $Parent $TextBox
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (TextBox)"
    Update-WPFObject $TextBox $ScriptBlock

    if ($this.Parent) { return }
    return $TextBox
}
