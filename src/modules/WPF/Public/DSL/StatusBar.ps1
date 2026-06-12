<#
.SYNOPSIS
    Creates a WPF StatusBar object.

.DESCRIPTION
    Supports both named and nameless forms:

    StatusBar 'Footer' { ... }
    StatusBar { ... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.statusbar
#>
function StatusBar {
    [CmdletBinding()]
    [Alias('-StatusBar')]
    [OutputType([void], [System.Windows.Controls.Primitives.StatusBar])]
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
        throw 'StatusBar requires a scriptblock.'
    }

    if ($null -ne $Name) {
        $Name = [string] $Name
        if ([string]::IsNullOrWhiteSpace($Name)) {
            throw 'StatusBar name cannot be empty.'
        }

        if ($Name -notmatch '^\w+$') {
            throw "Invalid StatusBar name '$Name'. Name must match '^\\w+$'."
        }
    }

    try {
        $StatusBar = if ($Name) {
            [System.Windows.Controls.Primitives.StatusBar] @{
                Name = $Name
            }
        } else {
            [System.Windows.Controls.Primitives.StatusBar]::new()
        }

        if ($Name) {
            Register-WPFObject $Name $StatusBar
        }

        Add-WPFType $StatusBar 'Control'
    } catch {
        $StatusBarName = if ($Name) { $Name } else { '__Nameless__' }
        Write-Error "Failed to create '$StatusBarName' (StatusBar) with error: $_"
    }

    $Parent = $PSCmdlet.GetVariableValue('this')
    $WasAutoAttached = $false
    if ($Parent -and -not $StatusBar.Parent) {
        $AppRootProperty = $Parent.PSObject.Properties['_WPFAppRoot']
        $AppContentProperty = $Parent.PSObject.Properties['_WPFAppContent']

        if ($Parent -is [System.Windows.Window] -and $AppRootProperty -and $AppRootProperty.Value -and $AppContentProperty -and $AppContentProperty.Value) {
            $StatusBarName = if ($Name) { $Name } else { '__Nameless__' }
            Write-Debug "Beginning app-statusbar auto-attach for $StatusBarName (StatusBar)"
            Add-WPFAppRootChild -Window $Parent -Child $StatusBar -Placement 'StatusBar'
            $WasAutoAttached = $true
        } else {
            $StatusBarName = if ($Name) { $Name } else { '__Nameless__' }
            Write-Debug "Beginning auto-attach for $StatusBarName (StatusBar)"
            Add-WPFObject $Parent $StatusBar
            $WasAutoAttached = $true
        }
    }

    $StatusBarName = if ($Name) { $Name } else { '__Nameless__' }
    Write-Debug "Processing child elements for $StatusBarName (StatusBar)"
    Update-WPFObject $StatusBar $ScriptBlock

    if (-not $WasAutoAttached) {
        return $StatusBar
    }
}
