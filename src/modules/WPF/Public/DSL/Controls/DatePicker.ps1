<#
.SYNOPSIS
    Creates a WPF DatePicker object.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -DatePicker 'MyDate' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.datepicker
#>
function DatePicker {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-DatePicker')]
    [OutputType([void], [System.Windows.Controls.DatePicker])]
    param(
        [Parameter(ParameterSetName = 'Name', Position = 0)]
        [ValidateScript({ -not ($_ -is [scriptblock]) })]
        [ValidatePattern('^\w+$')]
        [string] $Name = '__Nameless__',

        [Parameter(Mandatory, ParameterSetName = 'Name', Position = 1)]
        [Parameter(Mandatory, ParameterSetName = 'ScriptBlock', Position = 0)]
        [ScriptBlock] $ScriptBlock
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

    try {
        $DatePicker = [System.Windows.Controls.DatePicker]::new()
        if ($Name -ne '__Nameless__') {
            $DatePicker.Name = $Name
            Register-WPFObject $Name $DatePicker
        }
        Add-WPFType $DatePicker 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (DatePicker) with error: $_"
    }

    # Auto-attach if parent exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $DatePicker.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (DatePicker)"
        Update-WPFObject $Parent $DatePicker
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (DatePicker)"
    Update-WPFObject $DatePicker $ScriptBlock

    $IsParentedAfter = [bool] $DatePicker.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $DatePicker
    }
}
