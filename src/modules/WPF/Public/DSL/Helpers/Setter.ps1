<#
.SYNOPSIS
    Adds a setter to the current style or trigger.

.DESCRIPTION
    Resolves a dependency property on the current style or trigger target type
    and appends a WPF Setter. When -Resource is specified the value is stored as a
    DynamicResourceExtension so theme swaps update styled controls.

.EXAMPLE
    Setter Background ButtonBackground -Resource
#>
function Setter {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Property,

        [Parameter(Mandatory, Position = 1)]
        [AllowNull()]
        [object] $Value,

        [Parameter()]
        [switch] $Resource,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Target,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        $context = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }

        if ($context -is [System.Windows.Style]) {
            $targetType = $context.TargetType
            $setterCollection = $context.Setters
            $triggerOwner = $null
        } elseif (
            $context -is [System.Windows.Trigger] -or
            $context -is [System.Windows.DataTrigger] -or
            $context -is [System.Windows.MultiTrigger]
        ) {
            $targetType = $context.PSObject.Properties['_WPFTriggerTargetType'].Value
            $setterCollection = $context.Setters
            $triggerOwner = $context.PSObject.Properties['_WPFTriggerOwnerType'].Value
            if (-not $targetType) {
                Write-Error 'Setter: Trigger context is missing target type metadata.'
                return
            }
        } else {
            Write-Error 'Setter can only be used inside Style, Trigger, DataTrigger, or MultiTrigger.'
            return
        }

        $descriptor = [System.ComponentModel.DependencyPropertyDescriptor]::FromName($Property, $targetType, $targetType)
        if (-not $descriptor) {
            Write-Error "Setter: Property '$Property' is not a dependency property on type '$($targetType.FullName)'."
            return
        }

        $setterValue = if ($Resource) {
            [System.Windows.DynamicResourceExtension]::new([string] $Value)
        } else {
            $propertyType = $descriptor.PropertyType
            if ($null -ne $Value -and $propertyType -and -not $propertyType.IsInstanceOfType($Value)) {
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
                            Write-Error "Setter: Failed to convert '$Value' to '$($propertyType.FullName)' for property '$Property'."
                            return
                        }
                    } else {
                        Write-Error "Setter: Failed to convert '$Value' to '$($propertyType.FullName)' for property '$Property'."
                        return
                    }
                }
            } else {
                $Value
            }
        }

        $setter = [System.Windows.Setter]::new($descriptor.DependencyProperty, $setterValue)
        if ($Target) {
            if ($triggerOwner -ne 'ControlTemplate') {
                Write-Error 'Setter: -Target is only supported for triggers owned by ControlTemplate.'
                return
            }

            $setter.TargetName = $Target
        }

        $setterCollection.Add($setter) | Out-Null
    }
}
