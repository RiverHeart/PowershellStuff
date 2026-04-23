<#
.SYNOPSIS
    Adds a setter to the current style.

.DESCRIPTION
    Resolves a dependency property on the style target type and appends a WPF
    Setter. When -Resource is specified the value is stored as a
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

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        $style = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }
        if (-not ($style -is [System.Windows.Style])) {
            Write-Error 'Setter can only be used inside Style.'
            return
        }

        $targetType = $style.TargetType
        $descriptor = [System.ComponentModel.DependencyPropertyDescriptor]::FromName($Property, $targetType, $targetType)
        if (-not $descriptor) {
            Write-Error "Setter: Property '$Property' is not a dependency property on type '$($targetType.FullName)'."
            return
        }

        $setterValue = if ($Resource) {
            [System.Windows.DynamicResourceExtension]::new([string] $Value)
        } else {
            if ($Value -is [string]) {
                $propertyType = $descriptor.PropertyType
                if ($propertyType -and $propertyType -ne [string]) {
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
                    $Value
                }
            } else {
                $Value
            }
        }

        $style.Setters.Add([System.Windows.Setter]::new($descriptor.DependencyProperty, $setterValue)) | Out-Null
    }
}
