<#
.SYNOPSIS
    Adds an event trigger to a style or control template.

.DESCRIPTION
    Creates a System.Windows.EventTrigger for the specified routed event and
    appends it to the current Style or ControlTemplate.

    Routed events can be provided as:
    - a System.Windows.RoutedEvent object
    - an event name string (for example: 'Loaded')
    - an owner-qualified event name string (for example: 'Mouse.MouseEnter')

    The scriptblock runs with `$this` bound to the created EventTrigger so
    BeginStoryboard and StopStoryboard can add trigger actions.

.EXAMPLE
    Template {
        EventTrigger 'Mouse.MouseEnter' {
            BeginStoryboard 'HoverStoryboard' {
                Storyboard {
                    DoubleAnimation -Target 'GlassCube' -Property '(UIElement.Opacity)' -To 1 -Duration '0:0:0.2'
                }
            }
        }
    }
#>
function EventTrigger {
    [CmdletBinding()]
    [Alias('Add-WPFEventTrigger')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [object] $RoutedEvent,

        [Parameter(Mandatory, Position = 1)]
        [scriptblock] $ScriptBlock,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        $target = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }
        if (-not $target) {
            Write-Error 'EventTrigger: Unable to resolve current style or template context.'
            return
        }

        if ($target -is [System.Windows.Style]) {
            $targetType = $target.TargetType
        } elseif ($target -is [System.Windows.Controls.ControlTemplate]) {
            $targetType = $target.TargetType
        } else {
            Write-Error "EventTrigger: Unsupported target type '$($target.GetType().FullName)'. Use EventTrigger inside Style or ControlTemplate."
            return
        }

        if (-not $targetType) {
            Write-Error 'EventTrigger: Failed to resolve target type for trigger context.'
            return
        }

        $resolvedRoutedEvent = $null
        if ($RoutedEvent -is [System.Windows.RoutedEvent]) {
            $resolvedRoutedEvent = $RoutedEvent
        } elseif ($RoutedEvent -is [string]) {
            if ([string]::IsNullOrWhiteSpace($RoutedEvent)) {
                Write-Error 'EventTrigger: RoutedEvent string cannot be empty.'
                return
            }

            $eventOwnerType = $null
            $eventName = $RoutedEvent.Trim()

            $ownerQualifiedMatch = [System.Text.RegularExpressions.Regex]::Match(
                $eventName,
                '^\s*([\w\.]+)\.([\w]+)\s*$'
            )

            if ($ownerQualifiedMatch.Success) {
                $ownerTypeToken = $ownerQualifiedMatch.Groups[1].Value
                $eventName = $ownerQualifiedMatch.Groups[2].Value

                foreach ($assembly in [System.AppDomain]::CurrentDomain.GetAssemblies()) {
                    $candidate = $assembly.GetType($ownerTypeToken, $false, $true)
                    if ($candidate) {
                        $eventOwnerType = $candidate
                        break
                    }
                }

                if (-not $eventOwnerType) {
                    foreach ($assembly in [System.AppDomain]::CurrentDomain.GetAssemblies()) {
                        $candidate = $assembly.GetTypes() | Where-Object { $_.Name -ieq $ownerTypeToken } | Select-Object -First 1
                        if ($candidate) {
                            $eventOwnerType = $candidate
                            break
                        }
                    }
                }

                if (-not $eventOwnerType) {
                    Write-Error "EventTrigger: Could not resolve owner type '$ownerTypeToken' for routed event '$RoutedEvent'."
                    return
                }
            }

            if ($eventOwnerType) {
                $field = $eventOwnerType.GetField(
                    "$eventName`Event",
                    [System.Reflection.BindingFlags] 'Public, Static, FlattenHierarchy'
                )

                if ($field -and $field.FieldType -eq [System.Windows.RoutedEvent]) {
                    $resolvedRoutedEvent = $field.GetValue($null)
                }

                if (-not $resolvedRoutedEvent) {
                    $resolvedRoutedEvent = [System.Windows.EventManager]::GetRoutedEventsForOwner($eventOwnerType) |
                        Where-Object { $_.Name -ieq $eventName } |
                        Select-Object -First 1
                }
            }

            if (-not $resolvedRoutedEvent) {
                $lookupType = $targetType
                while ($lookupType -and -not $resolvedRoutedEvent) {
                    $resolvedRoutedEvent = [System.Windows.EventManager]::GetRoutedEventsForOwner($lookupType) |
                        Where-Object { $_.Name -ieq $eventName } |
                        Select-Object -First 1
                    $lookupType = $lookupType.BaseType
                }
            }

            if (-not $resolvedRoutedEvent) {
                Write-Error "EventTrigger: Could not resolve routed event '$RoutedEvent' for target type '$($targetType.FullName)'."
                return
            }
        } else {
            Write-Error 'EventTrigger: RoutedEvent must be a string or System.Windows.RoutedEvent.'
            return
        }

        $trigger = [System.Windows.EventTrigger]::new()
        $trigger.RoutedEvent = $resolvedRoutedEvent
        $trigger | Add-Member -NotePropertyName '_WPFTriggerHost' -NotePropertyValue $target -Force

        $PSVars = New-WPFVariableList -InputObject $trigger
        $null = $ScriptBlock.InvokeWithContext($null, $PSVars, @())

        $target.Triggers.Add($trigger) | Out-Null
    }
}
