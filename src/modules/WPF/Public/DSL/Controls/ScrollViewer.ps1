<#
.SYNOPSIS
    Creates a WPF ScrollViewer object.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -ScrollViewer 'MyViewer' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.scrollviewer
#>
function ScrollViewer {
    [CmdletBinding()]
    [Alias('-ScrollViewer')]
    [OutputType([void], [System.Windows.Controls.ScrollViewer])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\w+$')]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

    # Factory mode: inside a Template block, produce a FrameworkElementFactory
    # instead of a live ScrollViewer instance.
    if ($PSCmdlet.GetVariableValue('WPFFactoryContext') -eq $true) {
        $Factory = [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.ScrollViewer])
        $Factory.Name = $Name

        $Parent = $PSCmdlet.GetVariableValue('this')
        if ($Parent) {
            Add-WPFObject $Parent $Factory
        }

        Update-WPFObject $Factory $ScriptBlock

        if (-not $Parent) { return $Factory }
        return
    }

    try {
        $ScrollViewer = [System.Windows.Controls.ScrollViewer] @{
            Name = $Name
        }
        Register-WPFObject $Name $ScrollViewer
        Add-WPFType $ScrollViewer 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (ScrollViewer) with error: $_"
    }

    # Attach to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $ScrollViewer.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (ScrollViewer)"
        Update-WPFObject $Parent $ScrollViewer
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (ScrollViewer)"
    Update-WPFObject $ScrollViewer $ScriptBlock

    $IsParentedAfter = [bool] $ScrollViewer.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $ScrollViewer
    }
}
