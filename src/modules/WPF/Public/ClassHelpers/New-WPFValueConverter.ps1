<#
.SYNOPSIS
    Creates an IValueConverter backed by PowerShell scriptblocks.

.DESCRIPTION
    Use this helper when a WPF Binding requires a real IValueConverter instance
    but the conversion logic is easiest to express in PowerShell.

.EXAMPLE
    Binding 'WorkingSet64' {
        Converter = ValueConverter {
            param($Value)
            [math]::Round($Value / 1MB, 2)
        }
    }
#>
function New-WPFValueConverter {
    [Alias('ValueConverter')]
    [OutputType([ScriptValueConverter])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [scriptblock] $Convert,

        [Parameter(Position = 1)]
        [scriptblock] $ConvertBack
    )

    try {
        if ($ConvertBack) {
            return [ScriptValueConverter]::new($Convert, $ConvertBack)
        }

        return [ScriptValueConverter]::new($Convert)
    } catch {
        Write-Error "Failed to create ValueConverter with error: $_"
    }
}
