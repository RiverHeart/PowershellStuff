using namespace System
using namespace System.Windows
using namespace System.Management.Automation

class ThicknessConverter : PSTypeConverter
{
    [bool] CanConvertFrom([object] $SourceValue, [Type] $TargetType) {
        if ($TargetType -ne [System.Windows.Thickness]) {
            return $false
        }

        if ($SourceValue -is [string]) {
            $parts = $SourceValue.Split(',')
            if (
                $parts.Length -eq 4 -and
                [double]::TryParse($parts[0].Trim(), [ref]([double]$null)) -and
                [double]::TryParse($parts[1].Trim(), [ref]([double]$null)) -and
                [double]::TryParse($parts[2].Trim(), [ref]([double]$null)) -and
                [double]::TryParse($parts[3].Trim(), [ref]([double]$null))
            ) {
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

        if ($SourceValue -is [string]) {
            $parts = $SourceValue.Split(',')

            if ($parts.Length -eq 4 -and
                [double]::TryParse($parts[0].Trim(), [ref] $left) -and
                [double]::TryParse($parts[1].Trim(), [ref] $top) -and
                [double]::TryParse($parts[2].Trim(), [ref] $right) -and
                [double]::TryParse($parts[3].Trim(), [ref] $bottom)
            ) {
                return [System.Windows.Thickness]::new($left, $top, $right, $bottom)
            }
        } elseif ($SourceValue -is [object[]]) {
            if ($SourceValue.Length -eq 4 -and
                [double]::TryParse("$($SourceValue[0])", [ref] $left) -and
                [double]::TryParse("$($SourceValue[1])", [ref] $top) -and
                [double]::TryParse("$($SourceValue[2])", [ref] $right) -and
                [double]::TryParse("$($SourceValue[3])", [ref] $bottom)
            ) {
                return [System.Windows.Thickness]::new($left, $top, $right, $bottom)
            }
        }

        throw [System.NotSupportedException]::new("Cannot convert '$SourceValue' to $TargetType. Expected 'left,top,right,bottom'.")
    }

    [bool] CanConvertTo([object] $SourceValue, [Type] $TargetType) {
        return $false  # Not implemented
    }

    [object] ConvertTo([object] $SourceValue, [Type] $TargetType, [IFormatProvider] $FormatProvider, [bool] $IgnoreCase) {
        throw [System.NotSupportedException]::new("ConvertTo is not supported.")
    }
}

Update-TypeData -TypeName System.Windows.Thickness -TypeConverter ThicknessConverter -Force
