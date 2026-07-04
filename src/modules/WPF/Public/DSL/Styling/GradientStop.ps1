<#
.SYNOPSIS
    Adds a gradient stop to the current LinearGradientBrush.

.DESCRIPTION
    Converts a color string and offset to a GradientStop and appends it to the
    current LinearGradientBrush via `$this.GradientStops.Add(...)`.

    This keyword only works when the current context object is a
    System.Windows.Media.LinearGradientBrush.

.EXAMPLE
    LinearGradientBrush {
        GradientStop 'Yellow' 0.0
        GradientStop 'Red' 0.25
        GradientStop 'Blue' 0.75
        GradientStop 'LimeGreen' 1.0
    }
#>
function GradientStop {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Color,

        [Parameter(Mandatory, Position = 1)]
        [double] $Offset,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        $brush = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }
        if (-not ($brush -is [System.Windows.Media.LinearGradientBrush])) {
            Write-Error 'GradientStop can only be used inside LinearGradientBrush.'
            return
        }

        try {
            $convertedColor = [System.Windows.Media.ColorConverter]::ConvertFromString($Color)
            $stop = [System.Windows.Media.GradientStop]::new([System.Windows.Media.Color] $convertedColor, $Offset)
            $brush.GradientStops.Add($stop) | Out-Null
        } catch {
            Write-Error "GradientStop: Failed to add gradient stop color '$Color' at offset '$Offset'."
        }
    }
}
