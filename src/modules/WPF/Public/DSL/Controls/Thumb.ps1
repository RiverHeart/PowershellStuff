<#
.SYNOPSIS
    Creates a WPF Thumb object.

.EXAMPLE
    Creates a Thumb that reports drag movement.

    Thumb 'Handle' {
        On DragDelta { param($sender, $e) Write-Host "$($e.HorizontalChange), $($e.VerticalChange)" }
    }

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -Thumb 'MyThumb' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.primitives.thumb
#>
function Thumb {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-Thumb')]
    [OutputType([void], [System.Windows.Controls.Primitives.Thumb])]
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
        $Thumb = [System.Windows.Controls.Primitives.Thumb]::new()
        if ($Name -ne '__Nameless__') {
            $Thumb.Name = $Name
            Register-WPFObject $Name $Thumb
        }
        Add-WPFType $Thumb 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Thumb) with error: $_"
    }

    # Auto-attach if parent exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $Thumb.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (Thumb)"
        Update-WPFObject $Parent $Thumb
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (Thumb)"
    Update-WPFObject $Thumb $ScriptBlock

    $IsParentedAfter = [bool] $Thumb.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $Thumb
    }
}
