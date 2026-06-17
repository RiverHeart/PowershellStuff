<#
.SYNOPSIS
    Creates and registers a top-level Menu for a Window.

.DESCRIPTION
    Creates a new menu, registers it under the stable __WPFMenu alias, and caches
    it on the window object. Attaches to App root if available. Does not check for
    existing menu.

    Use Get-WPFMenu first to retrieve cached menu if it exists.
#>
function New-WPFMenu {
    [CmdletBinding()]
    [OutputType([System.Windows.Controls.Menu])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Window] $Window
    )

    $ContextId = Get-WPFControlContextId -InputObject $Window
    $MenuName = if ($Window.Name) { "__{0}Menu" -f $Window.Name } else { '__AppMenu' }
    $Menu = [System.Windows.Controls.Menu] @{
        Name = $MenuName
    }

    Register-WPFObject -Name $MenuName -InputObject $Menu -ContextId $ContextId
    Register-WPFObject -Name '__WPFMenu' -InputObject $Menu -ContextId $ContextId -Overwrite
    Add-WPFType $Menu 'Control'

    $RootProperty = $Window.PSObject.Properties['_WPFAppRoot']
    if ($RootProperty -and $RootProperty.Value) {
        Add-WPFAppRootChild -Window $Window -Child $Menu -Placement 'Menu'
    }

    $Window | Add-Member -NotePropertyName '_WPFMenu' -NotePropertyValue $Menu -Force

    return $Menu
}
