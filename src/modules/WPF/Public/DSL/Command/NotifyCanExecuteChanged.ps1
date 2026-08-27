<#
.SYNOPSIS
    Notifies relay commands that their CanExecute result may have changed.

.DESCRIPTION
    Resolves registered controls by name or accepts controls, reusable command
    definitions, and relay commands directly. Each distinct command is notified
    once per invocation.

.EXAMPLE
    NotifyCanExecuteChanged 'SaveButton', 'RefreshButton'

.EXAMPLE
    Reference 'SaveButton', 'RefreshButton' | NotifyCanExecuteChanged
#>
function NotifyCanExecuteChanged {
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    [OutputType([void])]
    param (
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({ Complete-WPFRegisteredObject @args })]
        [string[]] $Name,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'InputObject')]
        [ValidateNotNull()]
        [object] $InputObject,

        [Parameter(ParameterSetName = 'Name')]
        [string] $ContextId
    )

    begin {
        $NotifiedCommands = [System.Collections.Generic.List[object]]::new()
    }

    process {
        $Targets = if ($PSCmdlet.ParameterSetName -eq 'Name') {
            @(Reference -Name $Name -ContextId $ContextId -ErrorAction Stop)
        } else {
            @($InputObject)
        }

        foreach ($Target in $Targets) {
            $Command = if ($Target.PSObject.Methods['NotifyCanExecuteChanged']) {
                $Target
            } elseif ($Target.PSObject.Properties['Command']) {
                $Target.Command
            }

            if ($null -eq $Command -or -not $Command.PSObject.Methods['NotifyCanExecuteChanged']) {
                Write-Error `
                    -Message "NotifyCanExecuteChanged: Target does not expose a command with NotifyCanExecuteChanged()." `
                    -Category InvalidArgument `
                    -TargetObject $Target
                continue
            }

            $AlreadyNotified = $false
            foreach ($NotifiedCommand in $NotifiedCommands) {
                if ([object]::ReferenceEquals($NotifiedCommand, $Command)) {
                    $AlreadyNotified = $true
                    break
                }
            }

            if (-not $AlreadyNotified) {
                $Command.NotifyCanExecuteChanged()
                $NotifiedCommands.Add($Command)
            }
        }
    }
}
