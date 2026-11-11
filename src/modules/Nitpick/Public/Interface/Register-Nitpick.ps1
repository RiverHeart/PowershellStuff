<#
.SYNOPSIS
    Registers a given Nitpick rule or those that are discoverable via Find-Nitpick.

.DESCRIPTION
    Registers a given Nitpick rule or those that are discoverable via Find-Nitpick.

    This function can be used to register rules explicitly by providing a callable,
    or it can discover rules using the Find-Nitpick function when no callable is provided.

    IncludeRule and ExcludeRule parameters can be used to filter which discovered rules
    are registered.

    Explicit metadata overrides update an existing registration for the same
    callable. Without overrides, repeated registration retains the existing object.

.PARAMETER Applicability
    Optional ScriptBlock receiving one isolated IDictionary context and returning
    exactly one Boolean. Explicit null clears the predicate. When omitted,
    preserves the existing descriptor or Details declaration.

.PARAMETER MinimumAnalysisHostVersion
    Optional positive major/minor System.Version host prerequisite. Enforced only
    after applicability. Explicit null clears it; omission preserves metadata.

.EXAMPLE
    Register all discoverable Nitpick rules.

    Register-Nitpick

.EXAMPLE
    Register all discoverable Nitpick rules from a specific module.

    Register-Nitpick -Module MyModule

.EXAMPLE
    Register a new Nitpick rule named 'TestRule' with the specified callable, category, and source.
    With no explicit Namespace, scriptblock registrations default to Local/TestRule.

    Register-Nitpick `
        -Name TestRule `
        -Callable { param ($ScriptBlockAst) } `
        -Category Style `
        -Source Tests

.EXAMPLE
    Register a new Nitpick rule under an explicit namespace instead of the Local default.

    Register-Nitpick `
        -Namespace ProjectChecks `
        -Name TestRule `
        -Callable { param ($ScriptBlockAst) } `
        -Category Style `
        -Source Tests

.EXAMPLE
    Reconstruct a descriptor with a different category while preserving its
    applicability and analysis-host declarations.

    $Rule | Register-Nitpick -Category Quality -PassThru

.EXAMPLE
    Clear both optional execution declarations, including on an existing
    registration of the same callable.

    $Rule | Register-Nitpick -Applicability $null -MinimumAnalysisHostVersion $null
#>
function Register-Nitpick {
    [CmdletBinding(DefaultParameterSetName='Default')]
    # NOTE: NitpickRule won't be available at parse time to properly define it as an output type.
    [OutputType([void], [object])]
    param (
        [Parameter(ValueFromPipeline)]
        [ValidateScript({
            $_ -is [string] -or
            $_ -is [scriptblock] -or
            $_ -is [FunctionInfo] -or
            $_ -is [CmdletInfo] -or
            $_ -is [NitpickRule]
        })]
        [object[]] $Callable,

        [ValidateSet('Style', 'Quality', 'Security', 'Performance', 'Maintainability', 'Other')]
        [string] $Category,

        [bool] $EditorEnabled,

        [Parameter(HelpMessage='Optional scriptblock receiving one isolated IDictionary context argument. Must emit exactly one Boolean. False skips execution; errors terminate. Explicit null clears a declaration from Details.')]
        [AllowNull()]
        [object] $Applicability,

        [Parameter(HelpMessage='Optional minimum analysis host version. Explicit null clears a declaration from Details.')]
        [AllowNull()]
        [object] $MinimumAnalysisHostVersion,

        [Parameter(HelpMessage='Mandatory only when using a scriptblock')]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(HelpMessage='The namespace of the nitpick. Defaults to Local for scriptblocks and commands without an implementing module, or to the implementing module''s name.')]
        [ValidateNotNullOrEmpty()]
        [string] $Namespace,

        [Parameter(HelpMessage='Mandatory only when using a scriptblock')]
        [ValidateNotNullOrEmpty()]
        [string] $Source,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]] $Module,

        [string[]] $IncludeRule,
        [string[]] $ExcludeRule,

        [switch] $Force,
        [switch] $PassThru
    )

    begin {
        $Properties = @(
            'Name', 'Namespace', 'Category', 'EditorEnabled', 'Source',
            'Applicability', 'MinimumAnalysisHostVersion'
        )
    }

    process {
        if (-not $Callable) {
            Write-Verbose "No callable provided. Running discovery."

            $FindParams = @{}
            if ($Module) { $FindParams.Module = $Module }

            # NOTE: Maybe filter after constructing Nitpick if user provides the
            # rule id instead of the function name?
            $Callable = Find-Nitpick @FindParams
        }

        $HasOverrides = $Properties |
            Where-Object { $PSBoundParameters.ContainsKey($_) }

        foreach($CallableEntry in $Callable) {
            if ($CallableEntry -is [NitpickRule] -and -not $HasOverrides) {
                $Nitpick = $CallableEntry
            } else {
                # An already-constructed NitpickRule (for example piped from Find-Nitpick) can
                # still have its descriptive Category/Source/EditorEnabled metadata overridden
                # here; its own Name/Namespace/Category/EditorEnabled/Source are the defaults
                # for any override not explicitly bound, so its ID is preserved unless the
                # caller explicitly requests a different Name or Namespace.
                $BaseNitpick = if ($CallableEntry -is [NitpickRule]) { $CallableEntry } else { $null }
                $BaseCallable = if ($BaseNitpick) { $BaseNitpick.Callable } else { $CallableEntry }

                $NitpickParams = @{}
                foreach ($Property in $Properties) {
                    if ($PSBoundParameters.ContainsKey($Property)) {
                        $NitpickParams[$Property] = $PSBoundParameters[$Property]
                    } elseif ($BaseNitpick) {
                        $NitpickParams[$Property] = $BaseNitpick.$Property
                    }
                }

                $Nitpick = $BaseCallable | New-Nitpick @NitpickParams
            }

            if ($Nitpick.CallableType -ne 'ScriptBlock') {
                $ExpectedName = if ($Nitpick.Callable.Noun) {
                    $Nitpick.Callable.Noun
                } else {
                    $Nitpick.Callable.Name
                }

                if ($Nitpick.Name -ne $ExpectedName) {
                    Write-Error "Rule name '$($Nitpick.Name)' must match callable name '$ExpectedName'."
                    continue
                }
            }

            $Registry = Get-NitpickRegistry
            $IsIncluded = @($Nitpick) |
                Where-NitpickIncluded `
                    -PropertyPath Id `
                    -Include $IncludeRule `
                    -Exclude $ExcludeRule `
                    -Wildcard

            if (-not $IsIncluded) { continue }

            $Existing = $Registry.Nitpicks[$Nitpick.Id]
            if ($Existing) {
                $IsSame =
                    $Existing.Source -eq $Nitpick.Source -and
                    (Test-NitpickCallableIdentity -Left $Existing.Callable -Right $Nitpick.Callable)

                if ($IsSame -and -not $HasOverrides) {
                    Write-Verbose "Nitpick '$($Nitpick.Id)' is already registered."
                    if ($PassThru) {
                        Write-Output $Existing
                    }
                    continue
                }

                if (-not $IsSame -and -not $Force) {
                    Write-Error "A Nitpick with the ID '$($Nitpick.Id)' is already registered."
                    continue
                }
            }

            if ($Existing) {
                Write-Verbose "Overwriting existing Nitpick '$($Nitpick.Id)'."
            } else {
                Write-Verbose "Registering '$($Nitpick.Category)' rule '$($Nitpick.Id)'."
            }
            $Registry.Nitpicks[$Nitpick.Id] = $Nitpick

            if ($PassThru) {
                Write-Output $Nitpick
            }
        }
    }
}
