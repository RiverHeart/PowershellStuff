<#
.SYNOPSIS
    Creates a WPF Menu object.

.DESCRIPTION
    Creates a Menu control, registers it in the current context, and attempts to
    auto-attach to a parent Window or Menu if one exists. If the parent is a Window,
    also registers the Menu as a stable __WPFMenu alias for retrieval. Processes child
    elements defined in the script block.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.menu
#>
function Menu {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-Menu')]
    [OutputType([void], [System.Windows.Controls.Menu])]
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
        $Menu = [System.Windows.Controls.Menu]::new()
        if ($Name -ne '__Nameless__') {
            $Menu.Name = $Name
            Register-WPFObject $Name $Menu
        }
        Add-WPFType $Menu 'Control'

        # Register as stable __WPFMenu alias if parent is a Window
        $Parent = $PSCmdlet.GetVariableValue('this')
        if ($Parent -is [System.Windows.Window]) {
            $ContextId = Get-WPFControlContextId -InputObject $Parent -ErrorAction SilentlyContinue
            if ($ContextId) {
                Register-WPFObject -Name '__WPFMenu' -InputObject $Menu -ContextId $ContextId -Overwrite
            }
        }
    } catch {
        Write-Error "Failed to create '$Name' (Menu) with error: $_"
    }

    # Auto-attach self to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $Menu.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (Menu)"
        Update-WPFObject $Parent $Menu
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (Menu)"
    Update-WPFObject $Menu $ScriptBlock

    $IsParentedAfter = [bool] $Menu.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $Menu
    }
}

