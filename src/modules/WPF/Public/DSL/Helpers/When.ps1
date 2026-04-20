<#
.SYNOPSIS
    Keyword for adding an event handler to the current object.

.DESCRIPTION
    Adds an event handler to the given object. Injects the `$this variable
    into the scriptblock so handlers can reference their parent control.

.EXAMPLE
    Adds a handler for the 'Click' event to a button.

    Button 'MyButton' {
        When 'Click' {
            Write-Host "Button clicked"
        }
    }
#>
function When {
    [CmdletBinding()]
    [Alias('Add-WPFHandler')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({ Complete-WPFEvent @args })]
        [string] $Event,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,

        [object] $InputObject
    )

    # Auto-attach self to parent if one exists
    if (-not $InputObject) {
        $InputObject = $PSCmdlet.GetVariableValue('this')
        if (-not $InputObject) {
            Write-Warning "Parent not found for event handler '$Event'"
            return
        }
    }

    # While the most straightforward way to create an event handler
    # is to add the scriptblock to the event as-is, supporting the `$this
    # automatic variable complicates things.
    #
    # When the scriptblock is invoked as an event it, presumably,
    # executes in a child scope of the global session to prevent local
    # variables from overwriting global ones and the scope of the parent
    # object, a Window for instance, lives outside the scriptblock
    # we defined the handler in; where the `$this variable got injected.
    #
    # Because we cannot control the context under which the scriptblock will be
    # executed when the event triggers we use 'GetNewClosure()' here to create
    # a unique scope in which we can inject `$this into beforehand. Arguably,
    # this is a bit of over-engineering when you can call 'Reference' to get
    # the parent object by name but this makes `$this usage more consistent
    # and avoids a function call so... eh....
    $Closure = $ScriptBlock.GetNewClosure()
    $Closure.Module.SessionState.PSVariable.Set('this', $InputObject)

    # Remove polluted variables from session state
    $Closure.Module.SessionState.PSVariable.Remove('Event')
    $Closure.Module.SessionState.PSVariable.Remove('Scriptblock')
    $Closure.Module.SessionState.PSVariable.Remove('InputObject')

    Write-Debug "Adding handler for event '$Event' to object '$($InputObject.Name)' ($($InputObject.GetType().Name))"
    $InputObject."Add_$Event"($Closure)
}
