<#
.SYNOPSIS
    Keyword for creating or referencing a RoutedUICommand with keyboard shortcuts.

.DESCRIPTION
    Creates a new RoutedUICommand or references a built-in AppCommand, optionally
    binding keyboard shortcuts and a scriptblock handler.

    Supports both implicit form (command by name, handler only) and explicit form
    (command by name, shortcuts, and handler).

.EXAMPLE
    Reference a built-in command with a handler:

    Shortcut 'Open' {
        Get-WPFFileSelection
    }

    Create a custom command with shortcuts:

    Shortcut 'MyCommand' 'Ctrl+M' 'Alt+M' {
        Write-Host "Custom command executed"
    }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.input.routeduicommand
#>
function Shortcut {
    [CmdletBinding()]
    [Alias('-Shortcut')]
    [OutputType([System.Windows.Input.RoutedUICommand])]
    param(
        [Parameter(Mandatory,Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\w+$')]
        [ArgumentCompleter({ Complete-WPFApplicationCommand @args })]
        [string] $Name,

        [Parameter(Position=1)]
        [object] $ShortcutOrScriptBlock,

        [Parameter(Position=2)]
        [scriptblock] $ScriptBlock
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

    # Manual binding normalization: if position 1 is a scriptblock and ScriptBlock param is empty,
    # treat as implicit form (command reference only, no shortcuts).
    if ($ShortcutOrScriptBlock -is [scriptblock] -and -not $PSBoundParameters.ContainsKey('ScriptBlock')) {
        $ScriptBlock = $ShortcutOrScriptBlock
        $ShortcutOrScriptBlock = $null
    }

    if (-not $ScriptBlock) {
        throw 'Shortcut requires a scriptblock handler.'
    }

    try {
        $Parent = $PSCmdlet.GetVariableValue('this')

        # Check for built-in command.
        $CommandProperty = [System.Windows.Input.ApplicationCommands].GetProperty($Name)
        if ($CommandProperty) {
            $Command = $CommandProperty.GetValue($null, $null)
        }

        if (-not $Command -and -not $ShortcutOrScriptBlock) {
            throw [System.IO.InvalidDataException]::new("Failed to find ApplicationCommand '$Name'")
        } elseif (-not $Command) {

            # Convert shortcuts to an array of KeyGesture objects
            $KeyGestures = @()
            if ($ShortcutOrScriptBlock) {
                $KeyGestureConverter = [System.Windows.Input.KeyGestureConverter]::new()
                foreach($Item in @($ShortcutOrScriptBlock)) {
                    $KeyGestures += $KeyGestureConverter.ConvertFromString($Item)
                }
            }

            $Command = [System.Windows.Input.RoutedUICommand]::new(
                <# Text #> 'foo',
                <# Name #> $Name,
                <# OwnerType #> $Parent.GetType(),
                <# InputGestures #> $KeyGestures
            )
        }

        $Window = Get-WPFRegisteredObject 'Window'
        $Window.CommandBindings.Add([System.Windows.Input.CommandBinding]::new($Command, $ScriptBlock)) | Out-Null
        $Parent.Command = $Command
    } catch {
        Write-Error "Failed to create '$Name' (RoutedUICommand) with error: $_"
    }
}
