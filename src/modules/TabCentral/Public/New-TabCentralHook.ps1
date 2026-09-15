using namespace System.Management.Automation

<#
.SYNOPSIS
    Creates a new TabCentral hook.

.DESCRIPTION
    Creates a new TabCentral hook object with the specified properties.

.EXAMPLE
    Create scriptblock based hook

    $HookParams = @{
        Name = 'MyHook'
        Type = 'Completer'
        Callable = { param($word) $word }
        Source = 'MyModule'
    }
    $Hook = New-TabCentralHook @HookParams

.EXAMPLE
    Create function based hook

    $HookParams = @{
        Callable = 'Get-Command'
        Type = 'Completer'
    }
    $Hook = New-TabCentralHook @HookParams
#>
function New-TabCentralHook {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({
            $_ -is [string] -or
            $_ -is [scriptblock] -or
            $_ -is [FunctionInfo] -or
            $_ -is [CmdletInfo]
        })]
        [object] $Callable,

        [Parameter(Mandatory)]
        [ValidateSet('Completer', 'Modifier')]
        [string] $Type,

        [Parameter(HelpMessage='The name of the hook. Mandatory only when using a scriptblock')]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(HelpMessage='The source of the hook. Mandatory only when using a scriptblock')]
        [ValidateNotNullOrEmpty()]
        [string] $Source
    )

    $Hook = @{
        PSTypeName = 'TabCentral.Hook'
    }

    # Resolve strings to commands
    if ($Callable -is [string]) {
        $GetParams = @{
            Name = $Callable
            CommandType = 'Function', 'Cmdlet'
        }
        try {
            $Callable = Get-Command @GetParams
        } catch {
            Write-Error "Failed to resolve command: $Callable"
        }
    }

    # Validate callable accepts TabExpansion2 parameters
    Assert-TabCentralHookCallableSignature -TargetCallable $Callable -HookType $Type

    # Build hook
    if ($Callable -is [scriptblock]) {
        if (-not $Name -or -not $Source) {
            Write-Error "Name and Source are mandatory when using a scriptblock"
            return
        }
        $Hook.Name = $Name
        $Hook.Type = $Type
        $Hook.CallableType = 'ScriptBlock'
        $Hook.Callable = $Callable
        $Hook.Source = $Source
    } else {
        if (-not $Callable.ModuleName -and -not $Source) {
            Write-Error "Source is mandatory for non-module functions/cmdlets."
            return
        }

        # We don't want to hold onto references to the original object since
        # the module might get reloaded which could either invalidate the hook,
        # make it stale, or cause unexpected behavior.
        $Hook.Name = $Callable.Name
        $Hook.Type = $Type
        $Hook.CallableType = 'Function'
        $Hook.Callable = $Callable.Name
        $Hook.Source = if ($Callable.ModuleName) { $Callable.ModuleName } else { $Source }
    }

    return [pscustomobject] $Hook
}
