<#
.SYNOPSIS
    Creates a WPF DatePicker object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.datepicker
#>
function DatePicker {
    [CmdletBinding()]
    [OutputType([void], [System.Windows.Controls.DatePicker])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\w+$')]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    try {
        $DatePicker = [System.Windows.Controls.DatePicker] @{
            Name = $Name
        }
        Register-WPFObject $Name $DatePicker
        Add-WPFType $DatePicker 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (DatePicker) with error: $_"
    }

    # Auto-attach if parent exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($Parent) {
        Write-Debug "Beginning auto-attach for $Name (DatePicker)"
        Update-WPFObject $Parent $DatePicker
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (DatePicker)"
    Update-WPFObject $DatePicker $ScriptBlock

    if ($this.Parent) { return }
    return $DatePicker
}
