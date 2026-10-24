using namespace System.Windows.Controls

<#
.SYNOPSIS
    Moves a nested designer element onto the root design Canvas.

.DESCRIPTION
    Preserves the element's visual position and object identity while moving
    it out of its current container. Selection chrome is removed before the
    move and recreated after it so its event subscriptions remain valid.
#>
function Move-WpfDesignerElement {
    [CmdletBinding()]
    [OutputType([System.Windows.FrameworkElement])]
    param(
        [Parameter(Mandatory)]
        [System.Windows.FrameworkElement] $Element,

        [Parameter(Mandatory)]
        [System.Windows.FrameworkElement] $TargetContainer,

        [Parameter(Mandatory)]
        [object] $State,

        [System.Windows.Controls.Panel] $Panel
    )

    if ($TargetContainer -isnot [System.Windows.Controls.Canvas]) {
        throw "The target container type '$($TargetContainer.GetType().FullName)' is not supported."
    }
    if ($Element -eq $State.WindowFrame) {
        throw 'The Window frame cannot be moved.'
    }
    if (Test-PSType -InputObject $Element -TypeName 'Custom.WpfDesigner.Overlay') {
        throw 'Design-time overlays cannot be moved.'
    }

    $SourceParent = $Element.Parent
    if ($null -eq $SourceParent) {
        throw 'The element must be attached to a supported container before it can be moved.'
    }
    if ($SourceParent -eq $TargetContainer) {
        throw 'The element is already a direct child of the target Canvas.'
    }
    if ($SourceParent -isnot [System.Windows.Controls.Panel] -and
        $SourceParent -isnot [System.Windows.Controls.Decorator]
    ) {
        throw "The source container type '$($SourceParent.GetType().FullName)' is not supported."
    }

    $Position = Get-WpfDesignerCanvasRelativePosition -Canvas $TargetContainer -Target $Element
    $SourceIndex = if ($SourceParent -is [System.Windows.Controls.Panel]) {
        $SourceParent.Children.IndexOf($Element)
    } else {
        -1
    }
    $WasSelected = $State.SelectedElement -eq $Element

    if ($WasSelected) {
        Clear-WpfDesignerSelection -Canvas $TargetContainer -State $State -Panel $Panel
    }

    try {
        if ($SourceParent -is [System.Windows.Controls.Panel]) {
            $SourceParent.Children.Remove($Element)
        } else {
            $SourceParent.Child = $null
        }

        Add-WPFObject -InputObject $TargetContainer -ChildObjects $Element -ErrorAction Stop
        [System.Windows.Controls.Canvas]::SetLeft($Element, $Position.X)
        [System.Windows.Controls.Canvas]::SetTop($Element, $Position.Y)
        Select-WpfDesignerElement -Canvas $TargetContainer -Target $Element -State $State -Panel $Panel
    } catch {
        if ($Element.Parent -eq $TargetContainer) {
            $TargetContainer.Children.Remove($Element)
        }

        if ($SourceParent -is [System.Windows.Controls.Panel]) {
            $SourceParent.Children.Insert($SourceIndex, $Element)
        } else {
            $SourceParent.Child = $Element
        }

        if ($WasSelected -and $State.SelectedElement -ne $Element) {
            Select-WpfDesignerElement -Canvas $TargetContainer -Target $Element -State $State -Panel $Panel
        }
        throw
    }

    return $Element
}
