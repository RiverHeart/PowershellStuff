using namespace System
using namespace System.Windows
using namespace System.Management.Automation

<#
.SYNOPSIS
    Type converter for System.Windows.CornerRadius.

.DESCRIPTION
    This type converter allows converting from a string in the format "topLeft,topRight,bottomRight,bottomLeft"
    or from an array of 4 numeric values to a CornerRadius object. This is allows for a cleaner
    syntax when defining CornerRadius values in the DSL.

    CornerRadius is a struct used in WPF to represent the CornerRadius of a frame around a rectangle.
    It has four properties: TopLeft, TopRight, BottomRight, and BottomLeft. Margin and Padding properties in WPF
    often use CornerRadius to specify the amount of space around or inside a control.

.EXAMPLE
    # Using a string
    [System.Windows.CornerRadius] $CornerRadius = "10,20,30,40"
    # $CornerRadius is now a CornerRadius object with TopLeft=10, TopRight=20, BottomRight=30, BottomLeft=40

.EXAMPLE
    # Using an array
    [System.Windows.CornerRadius] $CornerRadius = 10, 20, 30, 40
    # $CornerRadius is now a CornerRadius object with TopLeft=10, TopRight=20, BottomRight=30, BottomLeft=40
#>
class CornerRadiusConverter : PSTypeConverter
{
    [bool] CanConvertFrom([object] $SourceValue, [Type] $TargetType) {
        if ($TargetType -ne [System.Windows.CornerRadius]) {
            return $false
        }

        if (
            $SourceValue -is [byte] -or
            $SourceValue -is [sbyte] -or
            $SourceValue -is [int16] -or
            $SourceValue -is [uint16] -or
            $SourceValue -is [int32] -or
            $SourceValue -is [uint32] -or
            $SourceValue -is [int64] -or
            $SourceValue -is [uint64] -or
            $SourceValue -is [single] -or
            $SourceValue -is [double] -or
            $SourceValue -is [decimal]
        ) {
            return $true
        }

        if ($SourceValue -is [string]) {
            $parts = $SourceValue.Split(',')

            # Uniform
            if (
                $parts.Length -eq 1 -and
                [double]::TryParse($parts[0].Trim(), [ref]([double]$null))
            ) {
                return $true

            # Symmetric
            } elseif ($parts.length -eq 2 -and
                [double]::TryParse($parts[0].Trim(), [ref]([double]$null)) -and
                [double]::TryParse($parts[1].Trim(), [ref]([double]$null))
            ) {
                return $true

            # Independent
            } elseif (
                $parts.Length -eq 4 -and
                [double]::TryParse($parts[0].Trim(), [ref]([double]$null)) -and
                [double]::TryParse($parts[1].Trim(), [ref]([double]$null)) -and
                [double]::TryParse($parts[2].Trim(), [ref]([double]$null)) -and
                [double]::TryParse($parts[3].Trim(), [ref]([double]$null))
            ) {
                return $true
            }
        # Uniform
        } elseif ($SourceValue -is [object[]] -and $SourceValue.Length -eq 1) {
            if ([double]::TryParse("$($SourceValue[0])", [ref]([double]$null))) {
                return $true
            }
        # Symmetric
        } elseif ($SourceValue -is [object[]] -and $SourceValue.Length -eq 2) {
            if (
                [double]::TryParse("$($SourceValue[0])", [ref]([double]$null)) -and
                [double]::TryParse("$($SourceValue[1])", [ref]([double]$null))
            ) {
                return $true
            }
        # Independent
        } elseif ($SourceValue -is [object[]] -and $SourceValue.Length -eq 4) {
            if (
                [double]::TryParse("$($SourceValue[0])", [ref]([double]$null)) -and
                [double]::TryParse("$($SourceValue[1])", [ref]([double]$null)) -and
                [double]::TryParse("$($SourceValue[2])", [ref]([double]$null)) -and
                [double]::TryParse("$($SourceValue[3])", [ref]([double]$null))
            ) {
                return $true
            }
        }

        return $false
    }

    [object] ConvertFrom([object] $SourceValue, [Type] $TargetType, [IFormatProvider] $FormatProvider, [bool] $IgnoreCase) {
        $topLeft = $null
        $topRight = $null
        $bottomRight = $null
        $bottomLeft = $null

        if (
            $SourceValue -is [byte] -or
            $SourceValue -is [sbyte] -or
            $SourceValue -is [int16] -or
            $SourceValue -is [uint16] -or
            $SourceValue -is [int32] -or
            $SourceValue -is [uint32] -or
            $SourceValue -is [int64] -or
            $SourceValue -is [uint64] -or
            $SourceValue -is [single] -or
            $SourceValue -is [double] -or
            $SourceValue -is [decimal]
        ) {
            $topLeft = [double] $SourceValue
            return [System.Windows.CornerRadius]::new($topLeft)
        }

        if ($SourceValue -is [string]) {
            $parts = $SourceValue.Split(',')

            # Uniform
            if ($parts.Length -eq 1 -and
                [double]::TryParse($parts[0].Trim(), [ref] $topLeft)
            ) {
                return [System.Windows.CornerRadius]::new($topLeft)

            # Symmetric
            } elseif ($parts.Length -eq 2 -and
                [double]::TryParse($parts[0].Trim(), [ref] $topLeft) -and
                [double]::TryParse($parts[1].Trim(), [ref] $topRight)
            ) {
                return [System.Windows.CornerRadius]::new($topLeft, $topRight, $topLeft, $topRight)

            # Independent
            } elseif ($parts.Length -eq 4 -and
                [double]::TryParse($parts[0].Trim(), [ref] $topLeft) -and
                [double]::TryParse($parts[1].Trim(), [ref] $topRight) -and
                [double]::TryParse($parts[2].Trim(), [ref] $bottomRight) -and
                [double]::TryParse($parts[3].Trim(), [ref] $bottomLeft)
            ) {
                return [System.Windows.CornerRadius]::new($topLeft, $topRight, $bottomRight, $bottomLeft)
            }
        } elseif ($SourceValue -is [object[]]) {
            # Uniform
            if ($SourceValue.Length -eq 1 -and
                [double]::TryParse("$($SourceValue[0])", [ref] $topLeft)
            ) {
                return [System.Windows.CornerRadius]::new($topLeft)

            # Symmetric
            } elseif ($SourceValue.Length -eq 2 -and
                [double]::TryParse("$($SourceValue[0])", [ref] $topLeft) -and
                [double]::TryParse("$($SourceValue[1])", [ref] $topRight)
            ) {
                return [System.Windows.CornerRadius]::new($topLeft, $topRight, $topLeft, $topRight)

            # Independent
            } elseif ($SourceValue.Length -eq 4 -and
                [double]::TryParse("$($SourceValue[0])", [ref] $topLeft) -and
                [double]::TryParse("$($SourceValue[1])", [ref] $topRight) -and
                [double]::TryParse("$($SourceValue[2])", [ref] $bottomRight) -and
                [double]::TryParse("$($SourceValue[3])", [ref] $bottomLeft)
            ) {
                return [System.Windows.CornerRadius]::new($topLeft, $topRight, $bottomRight, $bottomLeft)
            }
        }

        throw [System.NotSupportedException]::new("Cannot convert '$SourceValue' to $TargetType. Expected a single uniform value or 'topLeft,topRight,bottomRight,bottomLeft'.")
    }

    [bool] CanConvertTo([object] $SourceValue, [Type] $TargetType) {
        return $false  # Not implemented
    }

    [object] ConvertTo([object] $SourceValue, [Type] $TargetType, [IFormatProvider] $FormatProvider, [bool] $IgnoreCase) {
        throw [System.NotSupportedException]::new("ConvertTo is not supported.")
    }
}

Update-TypeData `
    -TypeName System.Windows.CornerRadius `
    -TypeConverter CornerRadiusConverter `
    -Force
