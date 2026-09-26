<#
.SYNOPSIS
    Finds valid Nitpick rules exported by loaded modules.

.DESCRIPTION
    Finds exported Test and Measure commands with the required Nitpick callable
    signature. Only modules already loaded in the current session are searched.

.EXAMPLE
    Returns all valid Nitpick rules from the currently loaded modules.

    Find-Nitpick

.EXAMPLE
    Returns all valid Nitpick rules from the specified modules.

    Find-Nitpick -Module Nitpick, MyNitpickRules

.EXAMPLE
    Pipes the output of Find-Nitpick to Register-Nitpick.

    Find-Nitpick | Register-Nitpick
#>
function Find-Nitpick {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.CommandInfo])]
    param (
        [string[]] $Module
    )

    $GetModuleParams = @{}
    if ($Module) {
        $GetModuleParams.Name = $Module
    }

    Get-Module @GetModuleParams |
        ForEach-Object {
            $_.ExportedCommands.Values |
                Where-Object {
                    $_.Verb -in 'Test', 'Measure' -and
                    $_.Parameters.Keys -contains 'ScriptBlockAst'
                }
        }
}
