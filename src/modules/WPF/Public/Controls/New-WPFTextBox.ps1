<#
.SYNOPSIS
    Creates a WPF TextBox object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.textbox
#>
function New-WPFTextBox {
    [Alias('TextBox')]
    [OutputType([System.Windows.Controls.TextBox])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [scriptblock] $ScriptBlock,

        [switch] $NoAutoAttach
    )

    try {
        $WPFObject = [System.Windows.Controls.TextBox] @{
            Name = $Name
        }
        Register-WPFObject $Name $WPFObject
        Add-WPFType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (TextBox) with error: $_"
    }

    # Auto-attach self to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('self')
    $WasAutoAttached = $False
    if (-not $NoAutoAttach -and $Parent -and -not $WPFObject.Parent) {
        Write-Debug "Beginning auto-attach for $Name (TextBox)"
        Update-WPFObject $Parent $WPFObject
        $WasAutoAttached = $True
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (TextBox)"
    Update-WPFObject $WPFObject $ScriptBlock

    if (-not $WasAutoAttached) {
        return $WPFObject
    }
}
