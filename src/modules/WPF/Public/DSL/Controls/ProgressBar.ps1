<#
.SYNOPSIS
    Creates a WPF ProgressBar object.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -ProgressBar 'MyProgressBar' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.progressbar
#>
function ProgressBar {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-ProgressBar')]
    [OutputType([void], [System.Windows.Controls.ProgressBar])]
    param(
        [Parameter(ParameterSetName = 'Name', Position = 0)]
        [ValidateScript({ $_ -isnot [scriptblock] })]
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
        $ProgressBar = [System.Windows.Controls.ProgressBar]::new()
        if ($Name -ne '__Nameless__') {
            $ProgressBar.Name = $Name
            Register-WPFObject $Name $ProgressBar
        }
        Add-WPFType $ProgressBar 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (ProgressBar) with error: $_"
    }

    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $ProgressBar.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (ProgressBar)"
        Update-WPFObject $Parent $ProgressBar
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (ProgressBar)"
    Update-WPFObject $ProgressBar $ScriptBlock

    $IsParentedAfter = [bool] $ProgressBar.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $ProgressBar
    }
}
