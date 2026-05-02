<#
.SYNOPSIS
    Creates a WPF Label object.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -Label 'MyLabel' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.label
#>
function Label {
    [CmdletBinding()]
    [Alias('-Label')]
    [OutputType([void], [System.Windows.Controls.Label])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\w+$')]
        [string] $Name,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

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
