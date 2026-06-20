<#
.SYNOPSIS
    Adds a brush resource entry to the current theme dictionary.

.DESCRIPTION
    Converts a color string to SolidColorBrush and stores it under a key on
    the current Theme dictionary.

.EXAMPLE
    Theme 'Light' {
        Brush 'WindowBackground' '#FFFFFF'
    }
#>
function Brush {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Key,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $Color,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        $dictionary = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }
        if (-not ($dictionary -is [System.Windows.ResourceDictionary])) {
            Write-Error 'Brush can only be used inside Theme.'
            return
        }

        $converter = [System.Windows.Media.BrushConverter]::new()
        try {
            $dictionary[$Key] = $converter.ConvertFromString($Color)
        } catch {
            Write-Error "Invalid brush color '$Color'."
        }
    }
}
