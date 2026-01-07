<#
.SYNOPSIS
    Creates a RelayCommand object implementing ICommand.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.button
#>
function New-WPFRelayCommand {
    [Alias('RelayCommand')]
    [OutputType([RelayCommand])]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $Execute,
        [scriptblock] $CanExecute
    )

    try {
        $Command =
            if ($CanExecute) {
                [RelayCommand]::new($Execute, $CanExecute)
            } else {
                [RelayCommand]::new($Execute)
            }

        Set-WPFObjectType $Command 'Command'
    } catch {
        Write-Error "Failed to create Command with error: $_"
    }

    return $Command
}
