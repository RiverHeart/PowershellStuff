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
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Shortcut,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    $Parent = $PSCmdlet.GetVariableValue('self')

    # Stupid trash needs a Window.CommandBinding...
    # If we can access self from this function then maybe we can
    # assign it from here?

    $KeyGestures = @()
    $KeyGestureConverter = [System.Windows.Input.KeyGestureConverter]::new()
    foreach($Item in $Shortcut) {
        $KeyGestures += $KeyGestureConverter.ConvertFromString($Item)
    }

    try {
        $RoutedUICommand = [System.Windows.Input.RoutedUICommand]::new(
            <# Text #> 'foo',
            <# Name #> $Name,
            <# OwnerType #> $Parent.GetType(),
            <# InputGestures #> $KeyGestures
        )
        $Window = Get-WPFRegisteredObject 'Window'  # TODO: Going to fail if there isn't a static reference
        $Window.CommandBindings.Add([System.Windows.Input.CommandBinding]::new($RoutedUICommand, $ScriptBlock)) | Out-Null
        $Parent.Command = $RoutedUICommand
    } catch {
        Write-Error "Failed to create '$Name' (RoutedUICommand) with error: $_"
    }
}
