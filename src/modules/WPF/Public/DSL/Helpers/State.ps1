<#
.SYNOPSIS
    Creates an observable state object for the current DSL parent.

.DESCRIPTION
    Initializes a New-WPFObservableState on the current parent's Tag property,
    making state bindable in templates and watchable via the Watch keyword.

    The usual convention is to call State inside the root Window block, but any
    DSL parent with a writable Tag property can host the state object.

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

    $Parent.Tag = New-WPFObservableState $Properties
}
