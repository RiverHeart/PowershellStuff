<#
.SYNOPSIS
    Helper for defining keyboard shortcuts in a WPF DSL.

.DESCRIPTION
    Keyword that registers a handler for `PreviewKeyDown` on the current object.
    It is syntax sugar that wraps your action in gesture-matching logic and only
    invokes the action when the key and modifier combination matches.

    Internally, `Key` registers this wrapper through `On PreviewKeyDown`.

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
        [string[]] $KeyGesture,

        [Parameter(Mandatory)]
        [scriptblock] $Action,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    begin {
        $IsDisabledBlock = $MyInvocation.InvocationName.StartsWith('-')
        if ($IsDisabledBlock) {
            Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name "Key $($KeyGesture -join ',')"
            return
        }

        $ParsedGestures = @(ConvertTo-KeyGesture -InputObject $KeyGesture)
    }

    process {
        if ($IsDisabledBlock) {
            return
        }

        # Auto-attach self to parent if one exists (must run per-invocation: $InputObject binds in process, not begin)
        if (-not $InputObject) {
            $InputObject = $PSCmdlet.GetVariableValue('WPFAutoAttachContext')
            if (-not $InputObject) {
                Write-Warning "Parent not found for event handler 'Key $($KeyGesture -join ',')'"
                return
            }
        }

        $PSVars = New-WPFVariableList -InputObject $InputObject
        $Handler = {
            param($sender, $event)
            Write-Debug "Key event detected: $($event.Key) with modifiers $($event.KeyboardDevice.Modifiers)"

            $GestureMatches = @($ParsedGestures | Where-Object {
                $event.Key -eq $_.Key -and $event.KeyboardDevice.Modifiers -eq $_.Modifiers
            })
            $IsMatch = $GestureMatches.Count -gt 0

            Write-Debug "Key match: $IsMatch"

            if ($IsMatch) {
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

        $InputObject | On PreviewKeyDown $Handler
    }
}
