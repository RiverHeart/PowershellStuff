using namespace System.Management.Automation

<#
.SYNOPSIS
    Creates a new Nitpick rule.

.DESCRIPTION
    Creates a new Nitpick rule object with the specified properties.

.EXAMPLE
    Create scriptblock based Nitpick rule

    $NitpickParams = @{
        Name = 'MyNitpick'
        Callable = { param($word) $word }
        Source = 'MyModule'
    }
    $Nitpick = New-Nitpick @NitpickParams

.EXAMPLE
    Create function based Nitpick rule

    $NitpickParams = @{
        Callable = 'Get-Command'
    }
    $Nitpick = New-Nitpick @NitpickParams
#>
function New-Nitpick {
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

        [Parameter(Mandatory,ParameterSetName='Default')]
        [ValidateSet('Style', 'Quality', 'Security', 'Performance', 'Maintainability', 'Other')]
        [string] $Type,

        [Parameter(HelpMessage='The name of the nitpick. Mandatory only when using a scriptblock')]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(HelpMessage='The source of the nitpick. Mandatory only when using a scriptblock')]
        [ValidateNotNullOrEmpty()]
        [string] $Source
    )

    $Nitpick = @{
        PSTypeName = 'Nitpick.Rule'
    }

    # Resolve strings to commands
    if ($Callable -is [string]) {
        $GetParams = @{
            Name = $Callable
            CommandType = 'Function', 'Cmdlet'
        }
        try {
            $Callable = Get-Command @GetParams -ErrorAction Stop
        } catch {
            Write-Error "Failed to resolve command: $Callable"
            return
        }
    }

    Assert-CallableSignature -TargetCallable $Callable -RequiredParams 'ScriptBlockAst'

    # Build nitpick
    if ($Callable -is [scriptblock]) {
        if (-not $Name -or -not $Source) {
            Write-Error "Name and Source are mandatory when using a scriptblock"
            return
        }
        $Nitpick.Name = $Name
        $Nitpick.Type = $Type
        $Nitpick.CallableType = 'ScriptBlock'
        $Nitpick.Callable = $Callable
        $Nitpick.Source = $Source
    } else {
        if (-not $Callable.ModuleName -and -not $Source) {
            Write-Error "Source is mandatory for non-module functions/cmdlets."
            return
        }

        # We don't want to hold onto references to the original object since
        # the module might get reloaded which could either invalidate it,
        # make it stale, or cause unexpected behavior.
        $Nitpick.Name = $Callable.Name
        $Nitpick.Type = $Type
        $Nitpick.CallableType = 'Function'
        $Nitpick.Callable = $Callable.Name
        $Nitpick.Source = if ($Callable.ModuleName) { $Callable.ModuleName } else { $Source }
    }

    return [pscustomobject] $Nitpick
}
