<#
.SYNOPSIS
    Creates a WPF RoutedUICommand object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.input.routeduicommand
#>
function New-WPFRoutedUICommand {
    [Alias('Shortcut')]
    [OutputType([System.Windows.Input.RoutedUICommand])]
    param(
        [Parameter(Mandatory,ParameterSetName='Existing',Position=0)]
        [Parameter(Mandatory,ParameterSetName='New',Position=0)]
        [ArgumentCompleter({ Complete-WPFApplicationCommand @args })]
        [string] $Name,

        [Parameter(Mandatory,ParameterSetName='New',Position=1)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Shortcut,

        [Parameter(Mandatory,ParameterSetName='Existing',Position=1)]
        [Parameter(Mandatory,ParameterSetName='New',Position=2)]
        [scriptblock] $ScriptBlock
    )

    try {
        $Parent = $PSCmdlet.GetVariableValue('self')

        # Check for built-in command.
        # QUESTION: Can we add extra shortcuts to built-in AppCommands?
        # If so, should probably get command first, built-in or new, then
        # use $Command.InputGestures.Add() to add them instead of putting them in a list.
        $CommandProperty = [System.Windows.Input.ApplicationCommands].GetProperty($Name)
        if ($CommandProperty) {
            $Command = $CommandProperty.GetValue($null, $null)
        }

        if (-not $Command -and $PSCmdlet.ParameterSetName -eq 'Existing') {
            throw [System.IO.InvalidDataException]::new("Failed to find ApplicationCommand '$Name'")
        } elseif (-not $Command) {

            # Convert shortcuts to an array of KeyGesture objects
            $KeyGestures = @()
            $KeyGestureConverter = [System.Windows.Input.KeyGestureConverter]::new()
            foreach($Item in $Shortcut) {
                $KeyGestures += $KeyGestureConverter.ConvertFromString($Item)
            }

            $Command = [System.Windows.Input.RoutedUICommand]::new(
                <# Text #> 'foo',
                <# Name #> $Name,
                <# OwnerType #> $Parent.GetType(),
                <# InputGestures #> $KeyGestures
            )
        }

        $Window = Get-WPFRegisteredObject 'Window'  # TODO: This is going to fail if we don't assign a static reference
        $Window.CommandBindings.Add([System.Windows.Input.CommandBinding]::new($Command, $ScriptBlock)) | Out-Null
        $Parent.Command = $Command
    } catch {
        Write-Error "Failed to create '$Name' (RoutedUICommand) with error: $_"
    }
}
