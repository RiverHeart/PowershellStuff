<#
.SYNOPSIS
    Shows temporary copy feedback in the Image Viewer toolbar and status bar.

.DESCRIPTION
    Displays a short-lived copy result indicator after the Copy button is pressed.

    On success, the Copy button icon switches to a check variant and the status
    details label shows "Copied to clipboard". On failure, the standard icon is
    retained and the status details label shows "Copy failed".

    Feedback automatically resets to the normal status display after a short delay.

.PARAMETER Success
    Indicates whether the clipboard copy succeeded.
#>
function Invoke-ImageViewerCopyFeedback {
    [CmdletBinding()]
    param(
        [switch] $Success
    )

    $Window = Get-WPFWindow
    $State = $Window.Tag

    if (-not $State.CopyFeedbackTimer) {
        $Timer = [System.Windows.Threading.DispatcherTimer]::new()
        $Timer.Interval = [TimeSpan]::FromMilliseconds(2000)
        $TimerWindow = $Window
        $TimerState = $State

        $null = $Timer.add_Tick({
            param($sender, $event)

            $sender.Stop()

            if (-not $TimerWindow.IsLoaded) {
                return
            }

            $TimerState.IsCopyFeedbackActive = $false

            Invoke-ImageViewerUpdateStatus
        }.GetNewClosure())

        $State.CopyFeedbackTimer = $Timer
    }

    $State.CopyFeedbackTimer.Stop()

    $DetailsLabel = Reference 'StatusDetailsLabel'
    if (-not $DetailsLabel) {
        return
    }

    if ($Success) {
        $State.IsCopyFeedbackActive = $true
        $DetailsLabel.Content = 'Copied to clipboard'
    } else {
        $State.IsCopyFeedbackActive = $false
        $DetailsLabel.Content = 'Copy failed'
    }

    $State.CopyFeedbackTimer.Start()
}
