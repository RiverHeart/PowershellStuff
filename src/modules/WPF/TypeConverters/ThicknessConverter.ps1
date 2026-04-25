using namespace System
using namespace System.Windows
using namespace System.Management.Automation

class ThicknessConverter : PSTypeConverter
{
    [bool] CanConvertFrom([object] $SourceValue, [Type] $TargetType) {
        if ($TargetType -ne [Thickness]) {
            return $false
        }

        if ($SourceValue -is [string]) {
            $parts = $SourceValue.Split(',')
            if ($parts.Length -eq 4) {
                return $true
            }
        } elseif ($SourceValue -is [object[]] -and $SourceValue.Length -eq 4) {
            return $true
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
                [double]::TryParse($parts[0], [ref] $left) -and
                [double]::TryParse($parts[1], [ref] $top) -and
                [double]::TryParse($parts[2], [ref] $right) -and
                [double]::TryParse($parts[3], [ref] $bottom)
            ) {
                return [Thickness]::new($left, $top, $right, $bottom)
            }
        } elseif ($SourceValue -is [object[]]) {
            if ($SourceValue.Length -eq 4 -and
                [double]::TryParse($SourceValue[0].ToString(), [ref] $left) -and
                [double]::TryParse($SourceValue[1].ToString(), [ref] $top) -and
                [double]::TryParse($SourceValue[2].ToString(), [ref] $right) -and
                [double]::TryParse($SourceValue[3].ToString(), [ref] $bottom)
            ) {
                return [Thickness]::new($left, $top, $right, $bottom)
            }
        }
        throw [System.NotSupportedException]::new("Cannot convert from $SourceValue to $TargetType")
    }

    [bool] CanConvertTo([object] $SourceValue, [Type] $TargetType) {
        return $false  # Not implemented
    }

    [object] ConvertTo([object] $SourceValue, [Type] $TargetType, [IFormatProvider] $FormatProvider, [bool] $IgnoreCase) {
        throw [System.NotSupportedException]::new("ConvertTo is not supported.")
    }
}

Update-TypeData -TypeName Thickness -TypeConverter ThicknessConverter -Force

function Test-ThicknessConverter {
    # Test string conversion
    $convertedFromString = [Thickness] "10,20,30,40"
    Write-Host "Converted from string: $convertedFromString"

    # Test array conversion
    $testArray = @(10, 20, 30, 40)
    $convertedFromArray = [Thickness] $testArray
    Write-Host "Converted from array: $convertedFromArray"
}

Test-ThicknessConverter
