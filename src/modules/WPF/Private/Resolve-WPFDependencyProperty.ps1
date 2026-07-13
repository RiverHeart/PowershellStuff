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
            [string] $OwnerTypeName,

            [Parameter(Mandatory)]
            [string] $PropertyName
        )

        $cacheKey = "$OwnerTypeName|$PropertyName"
        if ($script:WPFDependencyOwnerTypeCache.ContainsKey($cacheKey)) {
            return $script:WPFDependencyOwnerTypeCache[$cacheKey]
        }

        $ResolvedType = [System.Type]::GetType($OwnerTypeName, $false, $true)

        if (-not $ResolvedType) {
            $candidateTypes = [System.Collections.Generic.List[Type]]::new()
            foreach ($Assembly in [System.AppDomain]::CurrentDomain.GetAssemblies()) {
                try {
                    foreach ($type in $Assembly.ExportedTypes) {
                        if ($type.Name -ieq $OwnerTypeName -or $type.FullName -ieq $OwnerTypeName) {
                            $candidateTypes.Add($type)
                        }
                    }
                } catch {
                    continue
                }
            }

            if ($candidateTypes.Count -gt 0) {
                $bestScore = [int]::MinValue
                $bestType = $null
                foreach ($candidate in $candidateTypes) {
                    $score = 0

                    if ($candidate.FullName -ieq $OwnerTypeName) {
                        $score += 1000
                    } elseif ($candidate.Name -ieq $OwnerTypeName) {
                        $score += 100
                    }

                    if ([System.Windows.DependencyObject].IsAssignableFrom($candidate)) {
                        $score += 100
                    }

                    if ($candidate.Namespace -and $candidate.Namespace.StartsWith('System.Windows', [System.StringComparison]::OrdinalIgnoreCase)) {
                        $score += 50
                    }

                    $propertyField = $candidate.GetField("${PropertyName}Property", [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static -bor [System.Reflection.BindingFlags]::FlattenHierarchy)
                    if ($propertyField -and $propertyField.FieldType -eq [System.Windows.DependencyProperty]) {
                        $score += 200
                    }

                    if (
                        $null -eq $bestType -or
                        $score -gt $bestScore -or
                        ($score -eq $bestScore -and $candidate.FullName -lt $bestType.FullName)
                    ) {
                        $bestType = $candidate
                        $bestScore = $score
                    }
                }

                $ResolvedType = $bestType
            }
        }

        if ($ResolvedType) {
            $script:WPFDependencyOwnerTypeCache[$cacheKey] = $ResolvedType
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

    $OwnerType = Resolve-OwnerType -OwnerTypeName $OwnerTypeName -PropertyName $PropertyName
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
