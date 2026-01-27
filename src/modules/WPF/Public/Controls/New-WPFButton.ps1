<#
.SYNOPSIS
    Creates a WPF Button object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.button
#>
function New-WPFButton {
    [Alias('Button')]
    [OutputType([System.Windows.Controls.Button])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,

        [switch] $NoAutoAttach
    )

    try {
        $WPFObject = [System.Windows.Controls.Button] @{
            Name = $Name
            Content = $Content
        }
        Register-WPFObject $Name $WPFObject
        Add-WPFType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Button) with error: $_"
    }

    # Auto-attach self to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('self')
    $WasAutoAttached = $False
    if (-not $NoAutoAttach -and $Parent -and -not $WPFObject.Parent) {
        Write-Debug "Beginning auto-attach for $Name (Button)"
        Update-WPFObject $Parent $WPFObject
        $WasAutoAttached = $True
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (Button)"
    Update-WPFObject $WPFObject $ScriptBlock

    if (-not $WasAutoAttached) {
        return $WPFObject
    }
}
