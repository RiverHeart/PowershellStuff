<#
.SYNOPSIS
    Keyword for defining a command on a WPF control.

.DESCRIPTION
    Creates a RelayCommand or RoutedUICommand and assigns it to the current
    control's Command property.

    By default, the scriptblock is processed for child keyword specs:

    - Execute is always required.
    - If BoundTo is present, a RoutedUICommand is created and a CommandBinding
      is added to the specified registered object. Built-in ApplicationCommands
      (e.g. Open, Save) are recognised by name automatically.
    - If BoundTo is absent, a RelayCommand is created and assigned directly.
    - CanExecute is valid only for relay commands. Routed command enablement
      is handled by calling NotifyCanExecuteChanged on the command object
      explicitly when state changes.

    When a gesture string is provided without BoundTo, a RelayCommand is
    created and a KeyBinding is added to the registered Window's InputBindings.
    Mode is inferred automatically: if the scriptblock contains Execute,
    CanExecute, or BoundTo sub-keywords it is parsed as a command spec;
    otherwise the whole block is treated as the execute body.

.EXAMPLE
    Relay command:

    MenuItem '(H)elp/(A)bout' {
        Command 'About' {
            Execute { Show-About }
        }
    }

.EXAMPLE
    Relay command with CanExecute:

    MenuItem '(F)ile/(S)ave' {
        Command 'Save' {
            Execute { Save-File }
            CanExecute { $global:FileIsLoaded }
        }
    }

.EXAMPLE
    Relay command with keyboard gesture bound to the Window:

    MenuItem '(F)ile/(S)ave As' {
        Command 'SaveAs' 'Ctrl+Shift+S' {
            Execute { Save-FileAs }
            CanExecute { $global:FileIsLoaded }
        }
    }

.EXAMPLE
    Simple relay command with keyboard gesture (no Execute sub-keyword needed):

    MenuItem '(V)iew/(F)ullscreen' {
        Command 'FullScreen' 'F11' {
            Toggle-FullScreen
        }
    }

.EXAMPLE
    Routed command bound explicitly to the window:

    MenuItem '(F)ile/(O)pen' {
        Command 'Open' 'Ctrl+O' {
            BoundTo 'Window'
            Execute { Open-File }
        }
    }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.input.icommand
#>
function Command {
    [CmdletBinding()]
    [Alias('-Command')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\w+$')]
        [ArgumentCompleter({ Complete-WPFApplicationCommand @args })]
        [string] $Name,

        [Parameter(Position=1)]
        [object] $GesturesOrScriptBlock,

        [Parameter(Position=2)]
        [scriptblock] $ScriptBlock,

        [string] $BoundTo,

        # Explicit parent; supplied by wrapper keywords so that the correct
        # $this is forwarded without relying on scope-chain lookup.
        [object] $Parent
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

    # Normalize: if position 1 is a scriptblock and no explicit ScriptBlock supplied,
    # treat it as the scriptblock.
    if ($GesturesOrScriptBlock -is [scriptblock] -and -not $PSBoundParameters.ContainsKey('ScriptBlock')) {
        $ScriptBlock = $GesturesOrScriptBlock
        $GesturesOrScriptBlock = $null
    }

    if (-not $ScriptBlock) {
        Write-Error "Command '$Name' requires a scriptblock."
        return
    }

    if (-not $Parent) {
        $Parent = $PSCmdlet.GetVariableValue('this')
    }

    if (-not $Parent) {
        Write-Error "Command '$Name' must be called within a control's scriptblock."
        return
    }

    try {
        # Detect whether the block uses Execute/CanExecute/BoundTo sub-keywords by
        # scanning the AST rather than executing the block. This avoids side-effects
        # (e.g. opening dialogs) for plain scriptblocks that have no sub-keywords.
        $SubKeywords = 'Execute', 'CanExecute', 'BoundTo'
        $HasSubKeyword = [bool] $ScriptBlock.Ast.FindAll({
            param($Node)
            $Node -is [System.Management.Automation.Language.CommandAst] -and
            $Node.GetCommandName() -in $SubKeywords
        }, $false)

        if (-not $HasSubKeyword) {
            $ExecuteSpec = [pscustomobject] @{
                PSTypeName  = 'WPF.ExecuteSpec'
                ScriptBlock = $ScriptBlock
            }
            $CanExecuteSpec = $null
            $BoundToSpec = $null
        } else {
            # Execute the scriptblock as a keyword block and collect child spec objects.
            $PSVars     = New-WPFVariableList -InputObject $Parent
            $Children   = $ScriptBlock.InvokeWithContext($null, $PSVars)

            $ExecuteSpec    = @($Children | Where-Object { 'WPF.ExecuteSpec'    -in $_.PSTypeNames })[0]
            $CanExecuteSpec = @($Children | Where-Object { 'WPF.CanExecuteSpec' -in $_.PSTypeNames })[0]
            $BoundToSpec    = @($Children | Where-Object { 'WPF.BoundToSpec'    -in $_.PSTypeNames })[0]
        }

        $BoundToTarget = if ($BoundTo) {
            $BoundTo
        } elseif ($BoundToSpec) {
            $BoundToSpec.Target
        } else {
            $null
        }


        if ($BoundToTarget -and $CanExecuteSpec) {
            throw "Command '$Name': CanExecute is not supported for routed commands. " +
                  "Call NotifyCanExecuteChanged on the command object when state changes."
        }

        if ($GesturesOrScriptBlock -and -not $BoundToTarget) {
            # --- Relay command + Window KeyBinding path ---
            $Command = if ($CanExecuteSpec) {
                [RelayCommand]::new($ExecuteSpec.ScriptBlock, $CanExecuteSpec.ScriptBlock)
            } else {
                [RelayCommand]::new($ExecuteSpec.ScriptBlock)
            }

            $GestureStrings = @($GesturesOrScriptBlock)
            $Converter = [System.Windows.Input.KeyGestureConverter]::new()
            $Window = Get-WPFRegisteredObject 'Window'
            foreach ($GestureStr in $GestureStrings) {
                $Gesture = [System.Windows.Input.KeyGesture] $Converter.ConvertFromString($GestureStr)
                $Window.InputBindings.Add(
                    [System.Windows.Input.KeyBinding]::new($Command, $Gesture)
                ) | Out-Null
            }

            if ($Parent -is [System.Windows.Controls.MenuItem] -and $GestureStrings.Count -gt 0) {
                $Parent.InputGestureText = [string] $GestureStrings[0]
            }

        } elseif ($BoundToTarget) {
            # --- Routed / Application command path ---
            $AppProperty = [System.Windows.Input.ApplicationCommands].GetProperty($Name)
            $GestureStrings = @($GesturesOrScriptBlock)
            $InputGestures = [System.Windows.Input.InputGestureCollection]::new()
            if ($GesturesOrScriptBlock) {
                $Converter = [System.Windows.Input.KeyGestureConverter]::new()
                foreach ($Item in $GestureStrings) {
                    [void] $InputGestures.Add(
                        [System.Windows.Input.InputGesture] $Converter.ConvertFromString($Item)
                    )
                }
            }

            $Command = if ($AppProperty) {
                $AppCommand = [System.Windows.Input.RoutedUICommand] $AppProperty.GetValue($null, $null)
                if ($InputGestures.Count -gt 0) {
                    [System.Windows.Input.RoutedUICommand]::new(
                        <# Text          #> $AppCommand.Text,
                        <# Name          #> $AppCommand.Name,
                        <# OwnerType     #> $AppCommand.OwnerType,
                        <# InputGestures #> $InputGestures
                    )
                } else {
                    $AppCommand
                }
            } else {
                if ($InputGestures.Count -eq 0) {
                    throw "Command '$Name' is not a built-in ApplicationCommand. Provide at least one keyboard gesture."
                }

                [System.Windows.Input.RoutedUICommand]::new(
                    <# Text          #> $Name,
                    <# Name          #> $Name,
                    <# OwnerType     #> $Parent.GetType(),
                    <# InputGestures #> $InputGestures
                )
            }

            if ($Parent -is [System.Windows.Controls.MenuItem] -and $GestureStrings.Count -gt 0) {
                $Parent.InputGestureText = [string] $GestureStrings[0]
            }

            if (-not $ExecuteSpec) {
                throw "Command '$Name' requires an Execute block."
            }

            $BindingTarget = Get-WPFRegisteredObject $BoundToTarget
            $BindingTarget.CommandBindings.Add(
                [System.Windows.Input.CommandBinding]::new($Command, $ExecuteSpec.ScriptBlock)
            ) | Out-Null

        } else {
            # --- Pure relay command path (no gesture, no BoundTo) ---
            if (-not $ExecuteSpec) {
                throw "Command '$Name' requires an Execute block."
            }

            $Command = if ($CanExecuteSpec) {
                [RelayCommand]::new($ExecuteSpec.ScriptBlock, $CanExecuteSpec.ScriptBlock)
            } else {
                [RelayCommand]::new($ExecuteSpec.ScriptBlock)
            }
        }

        Set-WPFObjectSpec -InputObject $Parent -Name 'Command' -Value $Command | Out-Null
        Update-WPFObjectSpec -InputObject $Parent

    } catch {
        Write-Error "Failed to create command '$Name' with error: $_"
    }
}
