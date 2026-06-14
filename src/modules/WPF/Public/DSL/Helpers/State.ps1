<#
.SYNOPSIS
    Creates an observable state object for the current DSL parent.

.DESCRIPTION
    Initializes a New-WPFObservableState on the current parent's Tag property,
    making state bindable in templates and bindable via the Bind keyword.

    The usual convention is to call State inside the root Window block, but any
    DSL parent with a writable Tag property can host the state object.

.NOTES
    1) Use DataContext as the primary app/view state surface for anything you want to bind in WPF.
    2) Keep Tag for backward compatibility and ad hoc metadata, not as the main state channel.
    3) Do not blindly attach DataContext to every control. In WPF, DataContext inheritance is a feature, so setting it too low in the tree can accidentally override parent context and break bindings.

    Practical policy:

    1) Set state at the logical scope root (window, panel, or component root) using State.
    2) Let children inherit DataContext unless you intentionally need a local context boundary.
    3) Continue mirroring Tag to the same state object during transition to avoid breaking older Tag-based code.

.PARAMETER Properties
    A hashtable of initial property names and values for the observable state.

.EXAMPLE
    Window 'MyApp' {
        State @{
            Count = 0
            IsReady = $false
            TotalCpu = 0
        }

        TextBlock 'Counter' {
            BindProperty Text Count -Self
        }
    }
#>
function State {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNull()]
        [hashtable] $Properties
    )

    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($null -eq $Parent -or -not $Parent.PSObject.Properties['Tag']) {
        throw "State keyword requires a DSL parent with a writable Tag property"
    }

    $state = New-WPFObservableState $Properties
    $Parent.Tag = $state

    $dataContextProperty = $Parent.PSObject.Properties['DataContext']
    if ($null -ne $dataContextProperty -and $dataContextProperty.IsSettable) {
        $Parent.DataContext = $state
    }
}
