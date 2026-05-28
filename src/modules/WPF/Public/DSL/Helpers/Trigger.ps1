<#
.SYNOPSIS
    Adds a property trigger to a style or control template.

.DESCRIPTION
    Creates a System.Windows.Trigger for a dependency property and appends it
    to the current Style or ControlTemplate. When nested inside Chrome, the
    trigger is attached to the generated template chrome part.

    The scriptblock runs with `$this` bound to the created Trigger so Setter can
    add triggered values.

    Trigger blocks also support property command shorthand that maps to Setter.

.EXAMPLE
    Style 'PrimaryButton' Button {
        Trigger IsMouseOver $true {
            Opacity: 0.85
        }
    }

.EXAMPLE
    Trigger IsEnabled $false {
        Opacity: 0.6 -Target 'TemplateBorder'
    }

.EXAMPLE
    Style 'PrimaryButton' Button {
        Chrome {
            Trigger IsEnabled $false {
                BorderBrush: '#2563EB'
            }
        }
    }
#>
function Trigger {
    [CmdletBinding()]
    [Alias('Add-WPFTrigger')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Property,

        [Parameter(Mandatory, Position = 1)]
        [AllowNull()]
        [object] $Value,

        [Parameter(Mandatory, Position = 2)]
        [scriptblock] $ScriptBlock,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $SourceName,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        $target = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }
        if (-not $target) {
            Write-Error 'Trigger: Unable to resolve current style or template context.'
            return
        }

        $isChromeScopedTrigger = $false
        $chromeTargetName = $null
        $chromeTargetType = $null

        if ($target -is [System.Windows.Style]) {
            $targetType = $target.TargetType
            $triggerOwner = 'Style'
        } elseif ($target -is [System.Windows.Controls.ControlTemplate]) {
            $targetType = $target.TargetType
            $triggerOwner = 'ControlTemplate'
        } elseif ($target -is [System.Windows.FrameworkElementFactory]) {
            $chromeTemplate = $target.PSObject.Properties['_WPFChromeTemplate'].Value
            $chromeTargetName = $target.PSObject.Properties['_WPFChromeTargetName'].Value
            $chromeTargetType = $target.PSObject.Properties['_WPFChromeTargetType'].Value

            if ($null -eq $chromeTemplate -or [string]::IsNullOrWhiteSpace($chromeTargetName) -or $null -eq $chromeTargetType) {
                Write-Error "Trigger: Unsupported target type '$($target.GetType().FullName)'. Use Trigger inside Style, ControlTemplate, or Chrome."
                return
            }

            $target = $chromeTemplate
            $targetType = $target.TargetType
            $triggerOwner = 'ControlTemplate'
            $isChromeScopedTrigger = $true
        } else {
            Write-Error "Trigger: Unsupported target type '$($target.GetType().FullName)'. Use Trigger inside Style, ControlTemplate, or Chrome."
            return
        }

        if (-not $targetType) {
            Write-Error 'Trigger: Failed to resolve target type for trigger context.'
            return
        }

        $descriptor = [System.ComponentModel.DependencyPropertyDescriptor]::FromName($Property, $targetType, $targetType)
        if (-not $descriptor) {
            Write-Error "Trigger: Property '$Property' is not a dependency property on type '$($targetType.FullName)'."
            return
        }

        $propertyType = $descriptor.PropertyType
        $triggerValue = if ($null -ne $Value -and $propertyType -and -not $propertyType.IsInstanceOfType($Value)) {
            try {
                [System.Management.Automation.LanguagePrimitives]::ConvertTo($Value, $propertyType)
            } catch {
                if ($Value -is [string] -and $propertyType -ne [string]) {
                    try {
                        $converter = [System.ComponentModel.TypeDescriptor]::GetConverter($propertyType)
                        if ($converter -and $converter.CanConvertFrom([string])) {
                            $converter.ConvertFromInvariantString($Value)
                        } else {
                            $Value
                        }
                    } catch {
                        Write-Error "Trigger: Failed to convert '$Value' to '$($propertyType.FullName)' for property '$Property'."
                        return
                    }
                } else {
                    Write-Error "Trigger: Failed to convert '$Value' to '$($propertyType.FullName)' for property '$Property'."
                    return
                }
            }
        } else {
            $Value
        }

        $trigger = [System.Windows.Trigger]::new()
        $trigger.Property = $descriptor.DependencyProperty
        $trigger.Value = $triggerValue

        if ($SourceName) {
            if ($triggerOwner -ne 'ControlTemplate') {
                Write-Error 'Trigger: -SourceName is only supported inside ControlTemplate triggers.'
                return
            }

            $trigger.SourceName = $SourceName
        }

        $trigger | Add-Member -NotePropertyName '_WPFTriggerTargetType' -NotePropertyValue $targetType -Force
        $trigger | Add-Member -NotePropertyName '_WPFTriggerOwnerType' -NotePropertyValue $triggerOwner -Force

        if ($isChromeScopedTrigger) {
            $trigger | Add-Member -NotePropertyName '_WPFChromeTargetName' -NotePropertyValue $chromeTargetName -Force
            $trigger | Add-Member -NotePropertyName '_WPFChromeTargetType' -NotePropertyValue $chromeTargetType -Force
            $trigger | Add-Member -NotePropertyName '_WPFDefaultSetterScope' -NotePropertyValue 'Chrome' -Force
        }

        $implicitSetterFunctions = New-WPFImplicitSetterFunctionMap `
            -ScriptBlock $ScriptBlock `
            -TargetType $targetType `
            -ReservedCommands @('Setter') `
            -ContextName 'Trigger'

        $PSVars = New-WPFVariableList -InputObject $trigger
        $null = $ScriptBlock.InvokeWithContext($implicitSetterFunctions, $PSVars, @())

        $target.Triggers.Add($trigger) | Out-Null
    }
}
