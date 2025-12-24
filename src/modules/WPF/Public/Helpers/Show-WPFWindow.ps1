<#
.SYNOPSIS
   Reads in a string from a XAML generator script and converts
   it to XML.

.DESCRIPTION
   Reads in a string from a XAML generator script and converts
   it to XML.

   Provides basic error handling and resource cleanup.

.EXAMPLE
   New-WPFApp -Path $PSScriptRoot -Name Main
#>
function Show-WPFWindow {
    [CmdletBinding()]
    [OutputType([System.Nullable[bool]])]
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
