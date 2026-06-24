<#
.SYNOPSIS
    Creates a WPF Border object.

.DESCRIPTION
    Supports both named and nameless forms:

    Border 'MyBorder' { ... }
    Border { ... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.border

.EXAMPLE
    Creates a Border with a nested Label child.

    Border 'MyBorder' {
        Label 'MyLabel' {
            Content = 'Hello, world!'
        }
    }

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -Border 'MyBorder' { ...code... }
#>
function Border {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-Border')]
    [OutputType([void], [System.Windows.Controls.Border], [System.Windows.FrameworkElementFactory])]
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

    # Factory mode: inside a Template block, produce a FrameworkElementFactory
    # instead of a live Border instance.
    if ($PSCmdlet.GetVariableValue('WPFFactoryContext') -eq $true) {
        $Factory = [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.Border], $Name)

        $Parent = $PSCmdlet.GetVariableValue('this')
        if ($Parent) {
            Write-Debug "Factory auto-attach: $Name (Border) -> $($Parent.GetType().Name)"
            Add-WPFObject $Parent $Factory
        }

        Write-Debug "Processing factory children for $Name (Border)"
        Update-WPFObject $Factory $ScriptBlock

        if (-not $Parent) { return $Factory }
        return
    }

    try {
        $Border = [System.Windows.Controls.Border] @{
            Name = $Name
        }
        if ($Name -ne '__Nameless__') { Register-WPFObject $Name $Border }
        Add-WPFType $Border 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Border) with error: $_"
    }

    # Auto-attach if parent exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $Border.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (Border)"
        Update-WPFObject $Parent $Border
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $BorderName (Border)"
    Update-WPFObject $Border $ScriptBlock

    $IsParentedAfter = [bool] $Border.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $Border
    }
}
