<#
.SYNOPSIS
    Shows a WPF window modally and returns its dialog result.

.DESCRIPTION
    Activates the given window, calls ShowDialog(), stores the returned value in
    $global:LastDialogResult, and outputs the dialog result.

    In smoke-test mode (WPF_SMOKE_TEST enabled), the window auto-closes after first
    render so UI scripts can run unattended in automation.

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
        $SmokeAutoCloseHandler = $null

        try {
            if (Test-WPFSmokeTestMode) {
                Write-Debug "Smoke test mode enabled: Adding auto-close handler to '$($Window.Name)'"
                $SmokeAutoCloseHandler = {
                    param($Sender, $Args)

                    try {
                        if ($null -eq $Sender.DialogResult) {
                            # Closing via DialogResult keeps ShowDialog semantics intact.
                            $Sender.DialogResult = $false
                        } else {
                            $Sender.Close()
                        }
                    } catch {
                        $Sender.Close()
                    }
                }

                $Window.Add_ContentRendered($SmokeAutoCloseHandler)
            }

            # Activate before entering ShowDialog so the window gets keyboard focus at startup.
            $Window.Activate()

            # Set globally so you can reference `$LastDialogResult` plainly from the main script.
            $DialogResult = $Window.ShowDialog()
            $global:LastDialogResult = $DialogResult
            Write-Output $DialogResult
        } finally {
            if ($SmokeAutoCloseHandler) {
                $Window.Remove_ContentRendered($SmokeAutoCloseHandler)
            }

            $Window.Close()

            # Dispose all tracked disposable objects and clear the registry
            Clear-WPFControlRegistry
        }
    }
}
