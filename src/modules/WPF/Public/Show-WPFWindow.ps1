<#
.SYNOPSIS
   Reads in a string from a XAML generator script and converts
   it to XML

.EXAMPLE
   New-WPFApp -Path $PSScriptRoot -Name Main
#>
function Show-WPFWindow {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [System.Windows.Window] $Window
    )

    process {
        try {
            $Window.ShowDialog()
        } catch [Exception] {
            Write-Error "Window closed with error: $_"
        } finally {
            $Window.Close()
        }
    }
}
