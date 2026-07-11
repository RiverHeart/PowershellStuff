<#
.SYNOPSIS
    Adds a gradient stop to the current LinearGradientBrush.

.DESCRIPTION
    Converts a color string and offset to a GradientStop and appends it to the
    current parent object.

    This keyword only works when the current context object is either:

    - System.Windows.Media.LinearGradientBrush
    - System.Windows.Media.GradientStopCollection

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
        # WARNING: There is a weird edgecase with how GradientStopCollection is accessed
        # via `this`. It seems that it returns a value instead of the object so we can't
        # use GetVariableValue like we normally. Accessing the value off of the PSVariable
        # seems to work correctly.
        $PSVar = if ($null -ne $InputObject) {
            $InputObject
        } else {
            $PSCmdlet.SessionState.PSVariable.Get('this')
        }
        $Parent = $PSVar.Value
        if ($Parent -isnot [System.Windows.Media.LinearGradientBrush] -and
            $Parent -isnot [System.Windows.Media.GradientStopCollection]
        ) {
            Write-Error 'GradientStop can only be used inside LinearGradientBrush or GradientStopCollection.'
            return
        }

        try {
            $convertedColor = [System.Windows.Media.ColorConverter]::ConvertFromString($Color)
            $stop = [System.Windows.Media.GradientStop]::new([System.Windows.Media.Color] $convertedColor, $Offset)

            if ($Parent -is [System.Windows.Media.LinearGradientBrush]) {
                $Parent.GradientStops.Add($stop) | Out-Null
            } else {
                $Parent.Add($stop) | Out-Null
            }
        } catch {
            Write-Error "GradientStop: Failed to add gradient stop color '$Color' at offset '$Offset'."
        }
    }
}
