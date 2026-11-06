using namespace System.Collections
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Resolves and validates a Nitpick rule's dispatch parameter.

.DESCRIPTION
    Ensures a callable has one supported dispatch parameter and only the
    optional Context and reserved Details parameters in addition to it.
#>
function Resolve-NitpickDispatchSignature {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [object] $Callable
    )

    $Parameters = @(Get-CallableParameter -Callable $Callable)
    $CallableName = if ($Callable -is [scriptblock]) {
        '<scriptblock>'
    } else {
        $Callable.Name
    }

    $DispatchParameters = @(
        foreach ($Parameter in $Parameters) {
            $TypeName = $Parameter.ParameterType.Name
            if ($TypeName -eq 'AstDocument' -or
                $Parameter.ParameterType -eq [ScriptBlockAst]) {
                $Parameter
                continue
            }

            if ($Parameter.Name -eq 'ScriptBlockAst') {
                if ($Parameter.ParameterType -eq [object]) {
                    $Parameter
                    continue
                }

                throw (
                    "Invalid callable '$CallableName'. Parameter 'ScriptBlockAst' " +
                    "must be untyped, [object], [ScriptBlockAst], or [AstDocument]; " +
                    "found [$($Parameter.ParameterType.FullName)]."
                )
            }
        }
    )

    if ($DispatchParameters.Count -ne 1) {
        throw (
            "Invalid callable '$CallableName'. Expected exactly one dispatch parameter " +
            "named ScriptBlockAst or typed as ScriptBlockAst or AstDocument; " +
            "found $($DispatchParameters.Count)."
        )
    }

    $DispatchParameter = $DispatchParameters[0]
    $DetailsParameters = @()
    $ContextParameters = @()

    foreach ($Parameter in $Parameters) {
        if ($Parameter.Name -ieq $DispatchParameter.Name) {
            continue
        }

        if ($Parameter.Name -ieq 'Context') {
            if (-not [IDictionary].IsAssignableFrom($Parameter.ParameterType)) {
                throw "Invalid callable '$CallableName'. Context must be typed as System.Collections.IDictionary."
            }
            if ($Parameter.MandatoryParameterSets.Count -gt 0) {
                throw "Invalid callable '$CallableName'. Context must be optional."
            }
            $ContextParameters += $Parameter
            continue
        }

        if ($Parameter.Name -ieq 'Details') {
            if ($Parameter.ParameterType -ne [SwitchParameter]) {
                throw "Invalid callable '$CallableName'. Details must be a switch parameter."
            }
            $DetailsParameters += $Parameter
            continue
        }

        throw "Invalid callable '$CallableName'. Unsupported parameter '$($Parameter.Name)'."
    }

    if ($DetailsParameters.Count -gt 1) {
        throw "Invalid callable '$CallableName'. Details may be declared only once."
    }

    if ($DetailsParameters.Count -eq 1) {
        $DetailsParameter = $DetailsParameters[0]
        $DetailsSets = @(
            $DetailsParameter.ParameterSets |
                Where-Object { $_ -ne '__AllParameterSets' } |
                Select-Object -Unique
        )
        if ($DetailsSets.Count -ne 1 -or
            $DetailsParameter.ParameterSets -contains '__AllParameterSets' -or
            $DetailsParameter.MandatoryParameterSets -notcontains $DetailsSets[0]) {
            throw (
                "Invalid callable '$CallableName'. Details must be mandatory in one " +
                "separate parameter set."
            )
        }

        $DetailsSet = $DetailsSets[0]
        $DispatchInDetailsSet = $DispatchParameter.ParameterSets -contains '__AllParameterSets' -or
            $DispatchParameter.ParameterSets -contains $DetailsSet

        $ContextInDetailsSet = @(
            $ContextParameters | Where-Object {
                $_.ParameterSets -contains '__AllParameterSets' -or
                $_.ParameterSets -contains $DetailsSet
            }
        ).Count -gt 0

        if ($DispatchInDetailsSet -or $ContextInDetailsSet) {
            throw (
                "Invalid callable '$CallableName'. The Details parameter set must not " +
                "include the dispatch parameter or Context."
            )
        }

        $InvocationSets = @(
            $DispatchParameter.ParameterSets |
                Where-Object { $_ -ne '__AllParameterSets' }
        )

        if ($InvocationSets.Count -eq 0 -or @(
            $InvocationSets | Where-Object {
                $DispatchParameter.MandatoryParameterSets -notcontains $_
            }
        ).Count -gt 0) {
            throw (
                "Invalid callable '$CallableName'. The dispatch parameter must be " +
                "mandatory in an ordinary parameter set separate from Details."
            )
        }
    }

    if ($ContextParameters.Count -eq 1) {
        $DispatchSets = $DispatchParameter.ParameterSets -as [array]
        $ContextSets = $ContextParameters[0].ParameterSets -as [array]

        $HasSharedInvocationSet = if ($DispatchSets -contains '__AllParameterSets') {
            $ContextSets.Count -gt 0
        } elseif ($ContextSets -contains '__AllParameterSets') {
            $DispatchSets.Count -gt 0
        } else {
            @($DispatchSets | Where-Object { $ContextSets -contains $_ }).Count -gt 0
        }

        if (-not $HasSharedInvocationSet) {
            throw (
                "Invalid callable '$CallableName'. Context and the dispatch parameter " +
                "must share an ordinary parameter set."
            )
        }
    }

    [pscustomobject] @{
        DispatchParameterName = $DispatchParameter.Name
        DispatchType = if ($DispatchParameter.ParameterType -eq [object]) {
            [ScriptBlockAst]
        } else {
            $DispatchParameter.ParameterType
        }
    }
}
