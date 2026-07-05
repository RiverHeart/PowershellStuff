<#
.SYNOPSIS
    Resolves a WPF dependency property for DSL setter-style property names.

.DESCRIPTION
    Supports two input forms:

    - Property
      Resolves against the supplied target type using DependencyPropertyDescriptor.

    - Owner.Property
      Resolves owner-qualified attached-property syntax by first resolving the
      owner type, then resolving the property by descriptor or static
      <PropertyName>Property field lookup.

    Returns a record containing the resolved DependencyProperty and metadata,
    or $null when resolution fails.
#>
function Resolve-WPFDependencyProperty {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Property,

        [Parameter(Mandatory, Position = 1)]
        [Type] $TargetType
    )

    if (-not $script:WPFDependencyOwnerTypeCache) {
        $script:WPFDependencyOwnerTypeCache = [System.Collections.Generic.Dictionary[string, Type]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }

    function Resolve-OwnerType {
        param(
            [Parameter(Mandatory)]
            [string] $OwnerTypeName
        )

        if ($script:WPFDependencyOwnerTypeCache.ContainsKey($OwnerTypeName)) {
            return $script:WPFDependencyOwnerTypeCache[$OwnerTypeName]
        }

        $ResolvedType = [System.Type]::GetType($OwnerTypeName, $false, $true)
        if (-not $ResolvedType) {
            foreach ($Assembly in [System.AppDomain]::CurrentDomain.GetAssemblies()) {
                try {
                    $Match = $Assembly.ExportedTypes | Where-Object {
                        $_.Name -ieq $OwnerTypeName -or $_.FullName -ieq $OwnerTypeName
                    } | Select-Object -First 1
                } catch {
                    continue
                }

                if ($Match) {
                    $ResolvedType = $Match
                    break
                }
            }
        }

        if ($ResolvedType) {
            $script:WPFDependencyOwnerTypeCache[$OwnerTypeName] = $ResolvedType
        }

        return $ResolvedType
    }

    $OwnerTypeName = $null
    $PropertyName = $Property
    $IsOwnerQualified = $false

    if ($Property -match '^\s*(?<owner>[\w\.]+)\.(?<name>[\w]+)\s*$') {
        $OwnerTypeName = $Matches['owner']
        $PropertyName = $Matches['name']
        $IsOwnerQualified = $true
    }

    if (-not $IsOwnerQualified) {
        $Descriptor = [System.ComponentModel.DependencyPropertyDescriptor]::FromName($PropertyName, $TargetType, $TargetType)
        if (-not $Descriptor) {
            return $null
        }

        return [pscustomobject] @{
            DependencyProperty = $Descriptor.DependencyProperty
            PropertyType       = $Descriptor.PropertyType
            OwnerType          = $TargetType
            PropertyName       = $PropertyName
            IsAttached         = $false
            IsOwnerQualified   = $false
        }
    }

    $OwnerType = Resolve-OwnerType -OwnerTypeName $OwnerTypeName
    if (-not $OwnerType) {
        return $null
    }

    # Some attached-property owner types (for example ToolTipService) can throw
    # here instead of returning $null, so we fall back to static field lookup.
    try {
        $OwnerDescriptor = [System.ComponentModel.DependencyPropertyDescriptor]::FromName($PropertyName, $OwnerType, $OwnerType)
    } catch {
        $OwnerDescriptor = $null
    }

    if ($OwnerDescriptor) {
        return [pscustomobject] @{
            DependencyProperty = $OwnerDescriptor.DependencyProperty
            PropertyType       = $OwnerDescriptor.PropertyType
            OwnerType          = $OwnerType
            PropertyName       = $PropertyName
            IsAttached         = $true
            IsOwnerQualified   = $true
        }
    }

    $StaticFieldName = "${PropertyName}Property"
    $BindingFlags = [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static -bor [System.Reflection.BindingFlags]::FlattenHierarchy
    $StaticField = $OwnerType.GetField($StaticFieldName, $BindingFlags)
    if (-not $StaticField -or $StaticField.FieldType -ne [System.Windows.DependencyProperty]) {
        return $null
    }

    $DependencyProperty = $StaticField.GetValue($null)
    if (-not $DependencyProperty) {
        return $null
    }

    return [pscustomobject] @{
        DependencyProperty = $DependencyProperty
        PropertyType       = $DependencyProperty.PropertyType
        OwnerType          = $OwnerType
        PropertyName       = $PropertyName
        IsAttached         = $true
        IsOwnerQualified   = $true
    }
}
