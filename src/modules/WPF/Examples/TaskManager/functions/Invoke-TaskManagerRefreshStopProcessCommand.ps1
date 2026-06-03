function Invoke-TaskManagerRefreshStopProcessCommand {
    [CmdletBinding()]
    param()

    $button = Reference 'StopProcessButton'
    if ($null -eq $button) {
        return
    }

    $command = $button.Command
    if ($null -eq $command) {
        return
    }

    if ($command.PSObject.Methods['NotifyCanExecuteChanged']) {
        $command.NotifyCanExecuteChanged()
    }
}
