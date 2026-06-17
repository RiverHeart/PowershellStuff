<#
.SYNOPSIS
    Gets the top-level Menu for the resolved WPF context.

.DESCRIPTION
    Resolves a Menu using a stable alias first, then falls back to window-based
    lookup when needed. Works for App shell windows and plain Windows.

    If no menu exists in the resolved context, returns $null.

.EXAMPLE
    Get-WPFMenu

.EXAMPLE
    $Window = Get-WPFWindow
    Get-WPFMenu -Window $Window
#>
function Get-WPFMenu {
    [CmdletBinding()]
    [OutputType([System.Windows.Controls.Menu])]
    param(
        [System.Windows.Window] $Window,

        [Parameter(HelpMessage = 'Optional context id to resolve against.')]
        [string] $ContextId
    )

    $ResolvedContextId = $ContextId
    if (-not $ResolvedContextId -and $Window) {
        $ResolvedContextId = Get-WPFControlContextId -InputObject $Window -ErrorAction SilentlyContinue
    }

    if (-not $ResolvedContextId) {
        $ScopeObject = $PSCmdlet.GetVariableValue('this')
        $ResolvedContextId = Resolve-WPFControlContextId -ContextId $ContextId -InputObject $ScopeObject
    }

    if ($ResolvedContextId) {
        $ControlTable = Get-WPFControlTable -ContextId $ResolvedContextId -ErrorAction SilentlyContinue
        if ($ControlTable -and $ControlTable.ContainsKey('__WPFMenu')) {
            $RegisteredMenu = $ControlTable['__WPFMenu']
            if ($RegisteredMenu -is [System.Windows.Controls.Menu]) {
                return $RegisteredMenu
            }
        }
    } else {
        $RegisteredMenu = Reference '__WPFMenu' -ErrorAction SilentlyContinue
        if ($RegisteredMenu -is [System.Windows.Controls.Menu]) {
            return $RegisteredMenu
        }
    }

    if (-not $Window) {
        $Window = Get-WPFWindow -ContextId $ResolvedContextId -ErrorAction SilentlyContinue
        if (-not $Window) {
            return $null
        }
    }

    $CachedMenu = $Window.PSObject.Properties['_WPFMenu']
    if ($CachedMenu -and $CachedMenu.Value) {
        return $CachedMenu.Value
    }

    $ResolvedContextId = Get-WPFControlContextId -InputObject $Window -ErrorAction SilentlyContinue
    if ($ResolvedContextId) {
        $ControlTable = Get-WPFControlTable -ContextId $ResolvedContextId -ErrorAction SilentlyContinue
    }

    # Fallback: search window's App root if it exists
    $RootProperty = $Window.PSObject.Properties['_WPFAppRoot']
    if ($RootProperty -and $RootProperty.Value) {
        $Root = [System.Windows.Controls.DockPanel] $RootProperty.Value
        $ExistingMenu = @(
            $Root.Children |
                Where-Object { $_ -is [System.Windows.Controls.Menu] } |
                Select-Object -First 1
        )
        if ($ExistingMenu.Count -gt 0) {
            $Menu = [System.Windows.Controls.Menu] $ExistingMenu[0]
            if ($ResolvedContextId) {
                Register-WPFObject -Name '__WPFMenu' -InputObject $Menu -ContextId $ResolvedContextId -Overwrite
            }
            $Window | Add-Member -NotePropertyName '_WPFMenu' -NotePropertyValue $Menu -Force
            return $Menu
        }
    }

    # Final fallback: search entire window tree
    $Menu = Find-WPFChildNode -Node $Window -Type ([System.Windows.Controls.Menu])
    if ($Menu) {
        if ($ResolvedContextId) {
            Register-WPFObject -Name '__WPFMenu' -InputObject $Menu -ContextId $ResolvedContextId -Overwrite
        }
        $Window | Add-Member -NotePropertyName '_WPFMenu' -NotePropertyValue $Menu -Force
        return $Menu
    }

    return $null
}
