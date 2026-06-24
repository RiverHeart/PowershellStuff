<#
.SYNOPSIS
    Creates a WPF TextBlock object.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -TextBlock 'MyText' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.textblock
#>
function TextBlock {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-TextBlock')]
    [OutputType([void], [System.Windows.Controls.TextBlock])]
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
        $TextBlock = [System.Windows.Controls.TextBlock] @{
            Name = $Name
        }
        if ($Name -ne '__Nameless__') { Register-WPFObject $Name $TextBlock }
        Add-WPFType $TextBlock 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (TextBlock) with error: $_"
    }

    # Attach to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $TextBlock.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (TextBlock)"
        Update-WPFObject $Parent $TextBlock
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (TextBlock)"
    Update-WPFObject $TextBlock $ScriptBlock

    $IsParentedAfter = [bool] $TextBlock.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $TextBlock
    }
}
