function Enable-WPFAutoClose {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Windows.Window] $Window,

        [Parameter(Mandatory)]
        [double] $AutoCloseSeconds
    )

    if ($Window.Resources.Contains('WPFAutoCloseConfigured') -and $Window.Resources['WPFAutoCloseConfigured']) {
        return
    }

    $Window.Resources['WPFAutoCloseConfigured'] = $true

    $AutoCloseSecondsValue = [double] $AutoCloseSeconds
    $AutoCloseTimer = $null
    $AutoCloseHandler = $null
    $AutoCloseHandler = {
        param($Sender, $Args)
        Write-Debug ("[WPF] Auto-close trigger 'ContentRendered' fired for '{0}' with delay {1}s" -f $Sender.Name, $AutoCloseSecondsValue)

        try {
            if ($AutoCloseSecondsValue -le 0) {
                $Sender.Resources['WPFDialogCloseReason'] = 'AutoClose'
                if ($null -eq $Sender.DialogResult) {
                    $Sender.DialogResult = $false
                } else {
                    $Sender.Close()
                }
                return
            }

            if ($AutoCloseTimer) {
                $AutoCloseTimer.Stop()
                $AutoCloseTimer = $null
            }

            $AutoCloseTimer = [System.Windows.Threading.DispatcherTimer]::new()
            $AutoCloseTimer.Interval = [TimeSpan]::FromSeconds($AutoCloseSecondsValue)
            $null = $AutoCloseTimer.Add_Tick({
                try {
                    $Sender.Resources['WPFDialogCloseReason'] = 'AutoClose'
                    if ($null -eq $Sender.DialogResult) {
                        $Sender.DialogResult = $false
                    } else {
                        $Sender.Close()
                    }
                } catch {
                    $Sender.Close()
                } finally {
                    if ($AutoCloseTimer) {
                        $AutoCloseTimer.Stop()
                        $AutoCloseTimer = $null
                    }
                }
            }.GetNewClosure())

            $AutoCloseTimer.Start()
        } finally {
            if ($AutoCloseHandler) {
                $Sender.Remove_ContentRendered($AutoCloseHandler)
            }
        }
    }.GetNewClosure()

    Write-Debug ("[WPF] Auto-close enabled for '{0}' with delay {1}s" -f $Window.Name, $AutoCloseSecondsValue)
    $Window.Add_ContentRendered($AutoCloseHandler)
    $Window.Add_Closed({
        if ($AutoCloseTimer) {
            $AutoCloseTimer.Stop()
            $AutoCloseTimer = $null
        }
    }.GetNewClosure())
}
