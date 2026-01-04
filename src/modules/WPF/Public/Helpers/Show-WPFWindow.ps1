<#
.SYNOPSIS
    Calls `ShowDialog()`, `Activate()` and `Close()` on the given Window object.

.DESCRIPTION
    Calls `ShowDialog()`, `Activate()` and `Close()` on the given Window object.

    A `finally` block ensures that `Close()` gets called if the window closes or crashes.

.NOTES
    Unsure if I should be handling resource cleanup here.
    I tried doing that in the `finally` block but forgot that
    in some instances I was getting a value from an object
    after the window closes which requires the name to be registered.

.EXAMPLE
    New-WPFApp -Path $PSScriptRoot -Name Main
#>
function Show-WPFWindow {
    [CmdletBinding()]
    [OutputType([System.Nullable[bool]])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '', Justification='Because')]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [System.Windows.Window] $Window
    )

    process {
        try {
            # Set globally so you can reference `$LastDialogResult` plainly from the main script.
            $global:LastDialogResult = $Window.ShowDialog()
            $Window.Activate()
        } catch [Exception] {
            Write-Error "Window closed with error: $_"
        } finally {
            $Window.Close()
        }
    }
}
