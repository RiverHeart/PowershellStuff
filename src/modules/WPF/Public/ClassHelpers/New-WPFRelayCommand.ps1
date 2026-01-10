<#
.SYNOPSIS
    Creates a RelayCommand object implementing ICommand.

.NOTES
    If this ever takes a target it should support both taking an
    object and extracting the name or just the name itself.

    Also, Powershell strings don't need to be quoted unless they
    contain spaces so the appearance of a command, property, and string
    blurs a bit. The syntax below looks like explicit parameters but could
    just be key/value pairs that get mapped. Autocompletion of positional
    parameters could be handled by having an ArgumentCompleter that excludes
    bound positional params already given but this assumes we're creating
    parameters for each key/value pair instead of just accepting one
    key/value collection.

        RelayCommand
            Execute {
                Write-Host 'Foobar'
            }
            CanExecute {
                $True
            }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.button
#>
function New-WPFRelayCommand {
    [Alias('RelayCommand')]
    [OutputType([RelayCommand])]
    param(
        [Parameter(Mandatory,Position=1)]
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

        Add-WPFType $Command 'Command'
    } catch {
        Write-Error "Failed to create Command with error: $_"
    }

    return $Command
}
