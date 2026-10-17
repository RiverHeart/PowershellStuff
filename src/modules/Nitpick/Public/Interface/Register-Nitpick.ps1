<#
.SYNOPSIS
    Registers a given Nitpick rule or those that are discoverable via Find-Nitpick.

.DESCRIPTION
    Registers a given Nitpick rule or those that are discoverable via Find-Nitpick.

    This function can be used to register rules explicitly by providing a callable,
    or it can discover rules using the Find-Nitpick function when no callable is provided.

    IncludeRule and ExcludeRule parameters can be used to filter which discovered rules
    are registered.

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

    process {
        if (-not $Callable) {
            Write-Verbose "No callable provided. Running discovery."

            $FindParams = @{}
            if ($Module) { $FindParams.Module = $Module }

            # NOTE: Maybe filter after constructing Nitpick if user provides the
            # rule id instead of the function name?
            $Callable = Find-Nitpick @FindParams
        }

        $HasOverrides = @('Name', 'Namespace', 'Category', 'EditorEnabled', 'Source') |
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
                foreach ($Property in 'Name', 'Namespace', 'Category', 'Source') {
                    if ($PSBoundParameters.ContainsKey($Property)) {
                        $NitpickParams[$Property] = $PSBoundParameters[$Property]
                    } elseif ($BaseNitpick -and $BaseNitpick.$Property) {
                        $NitpickParams[$Property] = $BaseNitpick.$Property
                    }
                }
                if ($PSBoundParameters.ContainsKey('EditorEnabled')) {
                    $NitpickParams.EditorEnabled = $EditorEnabled
                } elseif ($BaseNitpick) {
                    $NitpickParams.EditorEnabled = $BaseNitpick.EditorEnabled
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
                Where-NitpickIncluded -PropertyPath Id -Include $IncludeRule -Exclude $ExcludeRule -Wildcard

            if (-not $IsIncluded) {
                continue
            }

            $Existing = $Registry.Nitpicks[$Nitpick.Id]
            if ($Existing) {
                $IsSame =
                    $Existing.Source -eq $Nitpick.Source -and
                    (Test-NitpickCallableIdentity -Left $Existing.Callable -Right $Nitpick.Callable)

                if ($IsSame) {
                    Write-Verbose "Nitpick '$($Nitpick.Id)' is already registered."
                    if ($PassThru) {
                        Write-Output $Existing
                    }
                    continue
                }

                if (-not $Force) {
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
