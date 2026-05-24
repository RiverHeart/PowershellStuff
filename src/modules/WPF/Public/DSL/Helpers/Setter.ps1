<#
.SYNOPSIS
    Adds a setter to the current style or trigger.

.DESCRIPTION
    Resolves a dependency property for the current context and applies a value.

    Supported contexts:
    - Style
    - Trigger/DataTrigger/MultiTrigger
    - Template factory elements (FrameworkElementFactory)

    In trigger contexts, -Target is supported only for ControlTemplate owners.
    When Trigger -Scope Chrome is used, Setter can use -Scope Chrome to target
    the generated chrome part.

    When -Resource is specified, the value is stored as a DynamicResourceExtension
    so theme swaps update styled controls.

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

        [Parameter()]
        [ValidateSet('Chrome')]
        [string] $Scope,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        $context = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }

        # FrameworkElementFactory context: use SetValue / SetResourceReference directly.
        if ($context -is [System.Windows.FrameworkElementFactory]) {
            if ($Target) {
                Write-Error 'Setter: -Target is not supported inside a FrameworkElementFactory context.'
                return
            }

            if ($Scope) {
                Write-Error 'Setter: -Scope is not supported inside a FrameworkElementFactory context.'
                return
            }

            $descriptor = [System.ComponentModel.DependencyPropertyDescriptor]::FromName($Property, $context.Type, $context.Type)
            if (-not $descriptor) {
                Write-Error "Setter: Property '$Property' is not a dependency property on type '$($context.Type.FullName)'."
                return
            }

            if ($Resource) {
                $context.SetResourceReference($descriptor.DependencyProperty, [string] $Value)
            } else {
                $propertyType = $descriptor.PropertyType
                $resolvedValue = if ($null -ne $Value -and $propertyType -and -not $propertyType.IsInstanceOfType($Value)) {
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
                $context.SetValue($descriptor.DependencyProperty, $resolvedValue)
            }
            return
        }

        if ($context -is [System.Windows.Style]) {
            if ($Scope) {
                Write-Error 'Setter: -Scope is only supported in trigger contexts.'
                return
            }

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

            $chromeTargetType = $context.PSObject.Properties['_WPFChromeTargetType'].Value
            $chromeTargetName = $context.PSObject.Properties['_WPFChromeTargetName'].Value
            $defaultScope = $context.PSObject.Properties['_WPFDefaultSetterScope'].Value

            $useChromeScope = ($Scope -eq 'Chrome') -or (($defaultScope -eq 'Chrome') -and -not $PSBoundParameters.ContainsKey('Scope'))
            if ($useChromeScope) {
                if ($triggerOwner -ne 'ControlTemplate') {
                    Write-Error 'Setter: -Scope Chrome is only supported for template-backed trigger contexts.'
                    return
                }

                if ($null -eq $chromeTargetType -or [string]::IsNullOrWhiteSpace($chromeTargetName)) {
                    Write-Error 'Setter: Trigger context is missing Chrome target metadata.'
                    return
                }

                if ($PSBoundParameters.ContainsKey('Target')) {
                    Write-Error 'Setter: Do not combine -Scope Chrome with -Target.'
                    return
                }

                $targetType = $chromeTargetType
                $Target = $chromeTargetName
            }
        } else {
            Write-Error 'Setter can only be used inside Style, Trigger, DataTrigger, MultiTrigger, or a Template factory element.'
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
