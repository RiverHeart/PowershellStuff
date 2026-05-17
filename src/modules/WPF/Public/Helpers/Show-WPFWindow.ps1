<#
.SYNOPSIS
    Shows a WPF window modally and returns its dialog result.

.DESCRIPTION
    Activates the given window, calls ShowDialog(), stores the returned value in
    $global:LastDialogResult, stores the close reason in
    $global:LastDialogCloseReason, and outputs the dialog result.

.PARAMETER Window
    The WPF window instance to display.

.EXAMPLE
    Window 'MainWindow' {
        $this.Title = 'Example'
    } | Show-WPFWindow
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
        $ContextId = $null

        try {
            $ContextId = Get-WPFControlContextId -InputObject $Window
            if ($ContextId) {
                if (-not $Window.Resources.Contains('WPFDialogCloseReason')) {
                    $Window.Resources['WPFDialogCloseReason'] = 'User'
                }
            }

            # Activate before entering ShowDialog so the window gets keyboard focus at startup.
            $Window.Activate()

            # Set globally so you can reference `$LastDialogResult` plainly from the main script.
            $DialogResult = $Window.ShowDialog()
            $global:LastDialogResult = $DialogResult

            if ($Window.Resources.Contains('WPFDialogCloseReason')) {
                $global:LastDialogCloseReason = [string] $Window.Resources['WPFDialogCloseReason']
            } else {
                $global:LastDialogCloseReason = 'User'
            }
            Write-Output $DialogResult
        } finally {
            if ($Window.IsLoaded) {
                $Window.Close()
            }

            # Only remove the shown window's context when it actually has one.
            # Helper dialogs created outside the DSL are not registered and must
            # not trigger active-context fallback removal.
            if ($ContextId) {
                Remove-WPFControlContext -ContextId $ContextId
            }
        }
    }
}
