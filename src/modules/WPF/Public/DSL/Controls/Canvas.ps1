<#
.SYNOPSIS
    Creates a WPF Canvas object.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -Canvas 'MyCanvas' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.canvas
#>
function Canvas {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-Canvas')]
    [OutputType([void], [System.Windows.Controls.Canvas], [System.Windows.FrameworkElementFactory])]
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

    if ($PSCmdlet.GetVariableValue('WPFFactoryContext') -eq $true) {
        if ($Name -ne '__Nameless__') {
            $Factory = [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.Canvas], $Name)
        } else {
            $Factory = [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.Canvas])
        }

        $Parent = $PSCmdlet.GetVariableValue('this')
        if ($Parent) {
            Add-WPFObject $Parent $Factory
        }

        Update-WPFObject $Factory $ScriptBlock

        if (-not $Parent) { return $Factory }
        return
    }

    try {
        $Canvas = [System.Windows.Controls.Canvas]::new()
        if ($Name -ne '__Nameless__') {
            $Canvas.Name = $Name
            Register-WPFObject $Name $Canvas
        }
        Add-WPFType $Canvas 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Canvas) with error: $_"
    }

    # Auto-attach to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $Canvas.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (Canvas)"
        Update-WPFObject $Parent $Canvas
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (Canvas)"
    Update-WPFObject $Canvas $ScriptBlock

    $IsParentedAfter = [bool] $Canvas.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $Canvas
    }
}
