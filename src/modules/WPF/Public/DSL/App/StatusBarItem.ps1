<#
.SYNOPSIS
    Creates a WPF StatusBarItem object.

.DESCRIPTION
    Supports both named and nameless forms:

    StatusBarItem 'ZoomHost' { ... }
    StatusBarItem { ... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.primitives.statusbaritem
#>
function StatusBarItem {
    [CmdletBinding()]
    [Alias('-StatusBarItem')]
    [OutputType([void], [System.Windows.Controls.Primitives.StatusBarItem])]
    param(
        [Parameter(Position = 0)]
        [object] $Name,

        [Parameter(Position = 1)]
        [ScriptBlock] $ScriptBlock
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

    if ($Name -is [scriptblock] -and -not $PSBoundParameters.ContainsKey('ScriptBlock')) {
        $ScriptBlock = $Name
        $Name = $null
    }

    if (-not $ScriptBlock) {
        throw 'StatusBarItem requires a scriptblock.'
    }

    if ($null -ne $Name) {
        $Name = [string] $Name
        if ([string]::IsNullOrWhiteSpace($Name)) {
            throw 'StatusBarItem name cannot be empty.'
        }

        if ($Name -notmatch '^\w+$') {
            throw "Invalid StatusBarItem name '$Name'. Name must match '^\\w+$'."
        }
    }

    try {
        $StatusBarItem = if ($Name) {
            [System.Windows.Controls.Primitives.StatusBarItem] @{
                Name = $Name
            }
        } else {
            [System.Windows.Controls.Primitives.StatusBarItem]::new()
        }

        if ($Name) {
            Register-WPFObject $Name $StatusBarItem
        }

        Add-WPFType $StatusBarItem 'Control'
    } catch {
        $StatusBarItemName = if ($Name) { $Name } else { '__Nameless__' }
        Write-Error "Failed to create '$StatusBarItemName' (StatusBarItem) with error: $_"
    }

    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $StatusBarItem.Parent
    if ($Parent -and -not $IsParentedBefore) {
        $StatusBarItemName = if ($Name) { $Name } else { '__Nameless__' }
        Write-Debug "Beginning auto-attach for $StatusBarItemName (StatusBarItem)"
        Update-WPFObject $Parent $StatusBarItem
    }

    $StatusBarItemName = if ($Name) { $Name } else { '__Nameless__' }
    Write-Debug "Processing child elements for $StatusBarItemName (StatusBarItem)"
    Update-WPFObject $StatusBarItem $ScriptBlock

    $IsParentedAfter = [bool] $StatusBarItem.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $StatusBarItem
    }
}
