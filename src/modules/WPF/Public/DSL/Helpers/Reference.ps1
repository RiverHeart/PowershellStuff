<#
.SYNOPSIS
    Returns a registered object by name.

.DESCRIPTION
    Returns a registered object by name.

    Objects are automatically registered at time of creation.

.NOTES
    It's not necessary to specify the type when assigning a reference to a variable,
    as PowerShell will infer the type from the registered object. However, it is recommended
    that you do so to take advantage of IntelliSense or ensure you're getting the object
    you think you are.

.EXAMPLE
    Get reference to the Window

    [System.Windows.Window] $Window = Reference 'Window'
#>
function Reference {
    [CmdletBinding()]
    [Alias('Get-WPFRegisteredObject')]
    [OutputType([void], [object])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\w+$')]
        [ArgumentCompleter({ Complete-WPFRegisteredObject @args })]
        [string[]] $Name,

        [Parameter(HelpMessage = 'Optional context id to resolve against.')]
        [string] $ContextId,

        [Parameter(HelpMessage = 'Optionally specify a property to select from the registered object. If not specified, the entire object will be returned.')]
        [string] $Property
    )

    process {
        $State = Get-WPFControlRegistry
        $ScopeObject = $PSCmdlet.GetVariableValue('this')

        foreach($Item in $Name) {
            if ($PSBoundParameters.ContainsKey('ContextId')) {
                if (-not (Test-WPFControlContextId -ContextId $ContextId -ErrorIfMissing)) {
                    return
                }

                $ResolvedContextId = $ContextId
            } else {
                $ResolveContextParams = @{}
                if ($ScopeObject -and (Get-WPFControlContextId -InputObject $ScopeObject)) {
                    $ResolveContextParams.InputObject = $ScopeObject
                }

                $ResolvedContextId = Resolve-WPFControlContextId @ResolveContextParams
            }

            $TargetObject = $null

            if ($ResolvedContextId -and $State.Contexts.ContainsKey($ResolvedContextId)) {
                $ControlTable = $State.Contexts[$ResolvedContextId].Objects
                if ($ControlTable.ContainsKey($Item)) {
                    $TargetObject = $ControlTable[$Item]
                }
            }

            if (-not $TargetObject) {
                $Matches = @(
                    foreach ($Context in $State.Contexts.Values) {
                        if ($Context.Objects.ContainsKey($Item)) {
                            [pscustomobject] @{
                                ContextId = $Context.Id
                                Name      = $Context.Name
                                Object    = $Context.Objects[$Item]
                            }
                        }
                    }
                )

                if ($Matches.Count -eq 1) {
                    $TargetObject = $Matches[0].Object
                } elseif ($Matches.Count -gt 1) {
                    $Hints = $Matches |
                        ForEach-Object {
                            if ($_.Name) {
                                "{0} ({1})" -f $_.ContextId, $_.Name
                            } else {
                                $_.ContextId
                            }
                        }
                    Write-Error "Reference '$Item' is ambiguous across contexts: $($Hints -join ', '). Specify -ContextId."
                    return
                }
            }

            if ($TargetObject) {
                if ($Property) {
                    $TargetObject | Select-Object -ExpandProperty $Property
                } else {
                    $TargetObject
                }
            } else {
                Write-Error "No object registered with name '$Item'"
                return
            }
        }
    }
}
