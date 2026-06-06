<#
.SYNOPSIS
    Helper for defining keyboard shortcuts in a WPF DSL.

.DESCRIPTION
    Keyword that registers a handler for `PreviewKeyDown` on the current object.
    It is syntax sugar that wraps your action in gesture-matching logic and only
    invokes the action when the key and modifier combination matches.

    Internally, `Key` registers this wrapper through `When PreviewKeyDown`.

.EXAMPLE
    Define a keyboard shortcut for Ctrl+Shift+S:

    Window 'MyWindow' {
        Key 'Ctrl+Shift+S' {
            Write-Host "Ctrl+Shift+S was pressed!"
        }
    }
#>
function Key {
    [CmdletBinding()]
    [Alias('-Key')]
    param(
        [Parameter(Mandatory)]
        [validateNotNullOrEmpty()]
        [string] $KeyGesture,

        [Parameter(Mandatory)]
        [scriptblock] $Action
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

    $ParsedGesture = ConvertTo-KeyGesture -InputObject $KeyGesture

    $this = $PSCmdlet.GetVariableValue('this')
    $PSVars = New-WPFVariableList -InputObject $this
    $Handler = {
        param($sender, $event)
        Write-Debug "Key event detected: $($event.Key) with modifiers $($event.KeyboardDevice.Modifiers)"

        $KeyDoesMatch = $event.Key -eq $ParsedGesture.Key
        $ModifiersMatch =
            $ParsedGesture.Modifiers -eq [System.Windows.Input.ModifierKeys]::None -or
            ($event.KeyboardDevice.Modifiers -band $ParsedGesture.Modifiers) -ne 0

        Write-Debug "Key match: $KeyDoesMatch, Modifiers match: $ModifiersMatch"

        if ($KeyDoesMatch -and $ModifiersMatch) {
            $RuntimeVars = [System.Collections.Generic.List[psvariable]]::new()
            if ($null -ne $PSVars) {
                foreach ($VarItem in @($PSVars)) {
                    if ($VarItem -is [psvariable]) {
                        $RuntimeVars.Add($VarItem)
                    }
                }
            }
            $RuntimeVars.Add([psvariable]::new('sender', $sender))
            $RuntimeVars.Add([psvariable]::new('event', $event))
            $RuntimeVars.Add([psvariable]::new('_', $event))
            $RuntimeVars.Add([psvariable]::new('PSItem', $event))
            $Action.InvokeWithContext($null, $RuntimeVars)
        }
    }.GetNewClosure()

    When PreviewKeyDown $Handler
}
