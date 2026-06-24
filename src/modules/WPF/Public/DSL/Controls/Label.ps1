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
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-Label')]
    [OutputType([void], [System.Windows.Controls.Label])]
    param(
        [Parameter(ParameterSetName = 'Name', Position = 0)]
        [ValidateScript({ -not ($_ -is [scriptblock]) })]
        [ValidatePattern('^\w+$')]
        [string] $Name = '__Nameless__',

        [Parameter(Mandatory, ParameterSetName = 'Name', Position = 1)]
        [Parameter(Mandatory, ParameterSetName = 'ScriptBlock', Position = 0)]
        [scriptblock] $ScriptBlock
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

    try {
        $Label = [System.Windows.Controls.Label]::new()
        if ($Name -ne '__Nameless__') {
            $Label.Name = $Name
            Register-WPFObject $Name $Label
        }
        Add-WPFType $Label 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Label) with error: $_"
    }

    # Auto-attach self to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $Label.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (Label)"
        Update-WPFObject $Parent $Label
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (Label)"
    Update-WPFObject $Label $ScriptBlock

    $IsParentedAfter = [bool] $Label.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $Label
    }
}
