<#
.SYNOPSIS
    Keyword for adding an event handler to the parent object.

.DESCRIPTION
    Keyword for adding an event handler to the parent object.

    For handlers bound through WPF Add_<Event> methods, PowerShell
    provides `$this` as the current sender object at invocation time,
    so this helper binds the original scriptblock directly instead of
    trying to inject `$this` manually.

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

    Write-Debug "Adding handler for event '$Event' to object '$($InputObject.Name)' ($($InputObject.GetType().Name))"
    $InputObject."Add_$Event"($ScriptBlock)
}
