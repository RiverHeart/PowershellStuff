<#
.SYNOPSIS
    Adds a multi-condition property trigger to a style or control template.

.DESCRIPTION
    Creates a System.Windows.MultiTrigger and appends it to the current Style
    or ControlTemplate.

    Conditions are provided as hashtables or objects with Property and Value
    members. SourceName is optional and only valid for ControlTemplate scope.

    The scriptblock runs with `$this` bound to the created MultiTrigger so
    Setter can add triggered values.

.EXAMPLE
    Style 'PrimaryButton' Button {
        MultiTrigger @(
            @{ Property = 'IsEnabled'; Value = $false }
            @{ Property = 'IsDefault'; Value = $true }
        ) {
            Setter Opacity 0.4
        }
    }

.EXAMPLE
    MultiTrigger @(
        @{ Property = 'IsEnabled'; Value = $false; SourceName = 'TemplateRoot' }
    ) {
        Setter Opacity 0.6 -Target 'TemplateRoot'
    }
#>
function MultiTrigger {
    [CmdletBinding()]
    [Alias('Add-WPFMultiTrigger')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [object[]] $Condition,

        [Parameter(Mandatory, Position = 1)]
        [scriptblock] $ScriptBlock,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        $target = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }
        if (-not $target) {
            Write-Error 'MultiTrigger: Unable to resolve current style or template context.'
            return
        }

        if ($target -is [System.Windows.Style]) {
            $targetType = $target.TargetType
            $triggerOwner = 'Style'
        } elseif ($target -is [System.Windows.Controls.ControlTemplate]) {
            $targetType = $target.TargetType
            $triggerOwner = 'ControlTemplate'
        } else {
            Write-Error "MultiTrigger: Unsupported target type '$($target.GetType().FullName)'. Use MultiTrigger inside Style or ControlTemplate."
            return
        }

        if (-not $targetType) {
            Write-Error 'MultiTrigger: Failed to resolve target type for trigger context.'
            return
        }

        $trigger = [System.Windows.MultiTrigger]::new()
        foreach ($conditionEntry in $Condition) {
            $entryObject = if ($conditionEntry -is [hashtable]) {
                [pscustomobject] $conditionEntry
            } else {
                $conditionEntry
            }

            $propertyName = $entryObject.PSObject.Properties['Property'].Value
            if ([string]::IsNullOrWhiteSpace($propertyName)) {
                Write-Error 'MultiTrigger: Each condition requires a non-empty Property value.'
                return
            }

            if (-not $entryObject.PSObject.Properties['Value']) {
                Write-Error "MultiTrigger: Condition for property '$propertyName' requires a Value entry."
                return
            }
            $rawValue = $entryObject.PSObject.Properties['Value'].Value

            $sourceName = $null
            if ($entryObject.PSObject.Properties['SourceName']) {
                $sourceName = $entryObject.PSObject.Properties['SourceName'].Value
            }

            $descriptor = [System.ComponentModel.DependencyPropertyDescriptor]::FromName($propertyName, $targetType, $targetType)
            if (-not $descriptor) {
                Write-Error "MultiTrigger: Property '$propertyName' is not a dependency property on type '$($targetType.FullName)'."
                return
            }

            $propertyType = $descriptor.PropertyType
            $conditionValue = if ($null -ne $rawValue -and $propertyType -and -not $propertyType.IsInstanceOfType($rawValue)) {
                try {
                    [System.Management.Automation.LanguagePrimitives]::ConvertTo($rawValue, $propertyType)
                } catch {
                    if ($rawValue -is [string] -and $propertyType -ne [string]) {
                        try {
                            $converter = [System.ComponentModel.TypeDescriptor]::GetConverter($propertyType)
                            if ($converter -and $converter.CanConvertFrom([string])) {
                                $converter.ConvertFromInvariantString($rawValue)
                            } else {
                                $rawValue
                            }
                        } catch {
                            Write-Error "MultiTrigger: Failed to convert '$rawValue' to '$($propertyType.FullName)' for property '$propertyName'."
                            return
                        }
                    } else {
                        Write-Error "MultiTrigger: Failed to convert '$rawValue' to '$($propertyType.FullName)' for property '$propertyName'."
                        return
                    }
                }
            } else {
                $rawValue
            }

            $wpfCondition = [System.Windows.Condition]::new()
            $wpfCondition.Property = $descriptor.DependencyProperty
            $wpfCondition.Value = $conditionValue

            if (-not [string]::IsNullOrWhiteSpace($sourceName)) {
                if ($triggerOwner -ne 'ControlTemplate') {
                    Write-Error 'MultiTrigger: SourceName is only supported inside ControlTemplate triggers.'
                    return
                }

                $wpfCondition.SourceName = [string] $sourceName
            }

            $trigger.Conditions.Add($wpfCondition) | Out-Null
        }

        $trigger | Add-Member -NotePropertyName '_WPFTriggerTargetType' -NotePropertyValue $targetType -Force
        $trigger | Add-Member -NotePropertyName '_WPFTriggerOwnerType' -NotePropertyValue $triggerOwner -Force

        $PSVars = New-WPFVariableList -InputObject $trigger
        $null = $ScriptBlock.InvokeWithContext($null, $PSVars)

        $target.Triggers.Add($trigger) | Out-Null
    }
}
