using namespace System
using namespace System.Windows
using namespace System.Management.Automation

<#
.SYNOPSIS
    Type converter for System.Windows.Thickness.

.DESCRIPTION
    This type converter allows converting from a string in the format "left,top,right,bottom"
    or from an array of 4 numeric values to a Thickness object. This is allows for a cleaner
    syntax when defining Thickness values in the DSL.

    Thickness is a struct used in WPF to represent the thickness of a frame around a rectangle.
    It has four properties: Left, Top, Right, and Bottom. Margin and Padding properties in WPF
    often use Thickness to specify the amount of space around or inside a control.

.EXAMPLE
    # Using a string
    [System.Windows.Thickness] $thickness = "10,20,30,40"
    # $thickness is now a Thickness object with Left=10, Top=20, Right=30, Bottom=40

.EXAMPLE
    # Using an array
    [System.Windows.Thickness] $thickness = 10, 20, 30, 40
    # $thickness is now a Thickness object with Left=10, Top=20, Right=30, Bottom=40
#>
class ThicknessConverter : PSTypeConverter
{
    [bool] CanConvertFrom([object] $SourceValue, [Type] $TargetType) {
        if ($TargetType -ne [System.Windows.Thickness]) {
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
            if (
                $parts.Length -eq 1 -and
                [double]::TryParse($parts[0].Trim(), [ref]([double]$null))
            ) {
                return $true
            }

            if (
                $parts.Length -eq 4 -and
                [double]::TryParse($parts[0].Trim(), [ref]([double]$null)) -and
                [double]::TryParse($parts[1].Trim(), [ref]([double]$null)) -and
                [double]::TryParse($parts[2].Trim(), [ref]([double]$null)) -and
                [double]::TryParse($parts[3].Trim(), [ref]([double]$null))
            ) {
                return $true
            }
        } elseif ($SourceValue -is [object[]] -and $SourceValue.Length -eq 1) {
            if ([double]::TryParse("$($SourceValue[0])", [ref]([double]$null))) {
                return $true
            }
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
        $left = $null
        $top = $null
        $right = $null
        $bottom = $null

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
            $left = [double] $SourceValue
            return [System.Windows.Thickness]::new($left)
        }

        if ($SourceValue -is [string]) {
            $parts = $SourceValue.Split(',')

            if ($parts.Length -eq 1 -and
                [double]::TryParse($parts[0].Trim(), [ref] $left)
            ) {
                return [System.Windows.Thickness]::new($left)
            }

            if ($parts.Length -eq 4 -and
                [double]::TryParse($parts[0].Trim(), [ref] $left) -and
                [double]::TryParse($parts[1].Trim(), [ref] $top) -and
                [double]::TryParse($parts[2].Trim(), [ref] $right) -and
                [double]::TryParse($parts[3].Trim(), [ref] $bottom)
            ) {
                return [System.Windows.Thickness]::new($left, $top, $right, $bottom)
            }
        } elseif ($SourceValue -is [object[]]) {
            if ($SourceValue.Length -eq 1 -and
                [double]::TryParse("$($SourceValue[0])", [ref] $left)
            ) {
                return [System.Windows.Thickness]::new($left)
            }

            if ($SourceValue.Length -eq 4 -and
                [double]::TryParse("$($SourceValue[0])", [ref] $left) -and
                [double]::TryParse("$($SourceValue[1])", [ref] $top) -and
                [double]::TryParse("$($SourceValue[2])", [ref] $right) -and
                [double]::TryParse("$($SourceValue[3])", [ref] $bottom)
            ) {
                return [System.Windows.Thickness]::new($left, $top, $right, $bottom)
            }
        }

        throw [System.NotSupportedException]::new("Cannot convert '$SourceValue' to $TargetType. Expected a single uniform value or 'left,top,right,bottom'.")
    }

    [bool] CanConvertTo([object] $SourceValue, [Type] $TargetType) {
        return $false  # Not implemented
    }

    [object] ConvertTo([object] $SourceValue, [Type] $TargetType, [IFormatProvider] $FormatProvider, [bool] $IgnoreCase) {
        throw [System.NotSupportedException]::new("ConvertTo is not supported.")
    }
}

Update-TypeData `
    -TypeName System.Windows.Thickness `
    -TypeConverter ThicknessConverter `
    -Force
