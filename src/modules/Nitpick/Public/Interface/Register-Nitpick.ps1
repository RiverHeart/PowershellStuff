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

    Register-Nitpick `
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

        [Parameter(HelpMessage='Mandatory only when using a scriptblock')]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(HelpMessage='Mandatory only when using a scriptblock')]
        [ValidateNotNullOrEmpty()]
        [string] $Source,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Module,

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

        foreach($CallableEntry in $Callable) {
            if ($CallableEntry -is [NitpickRule]) {
                $Nitpick = $CallableEntry
            } else {
                $NitpickParams = @{}
                if ($Name) { $NitpickParams.Name = $Name }
                if ($Category) { $NitpickParams.Category = $Category }
                if ($Source) { $NitpickParams.Source = $Source }

                $Nitpick = $CallableEntry | New-Nitpick @NitpickParams
            }

            $IsIncluded =
                ($null -eq $IncludeRule -or $Nitpick.Name -in $IncludeRule) -and
                ($null -eq $ExcludeRule -or $Nitpick.Name -notin $ExcludeRule)

            if (-not $IsIncluded) {
                continue
            }

            $Registry = Get-NitpickRegistry

            $Existing = $Registry.Nitpicks[$Nitpick.Name]
            if ($Existing) {
                $IsSame =
                    $Existing.Source -eq $Nitpick.Source -and
                    $Existing.Callable -eq $Nitpick.Callable

                if ($IsSame) {
                    Write-Verbose "Nitpick '$($Nitpick.Name)' is already registered."
                    if ($PassThru) {
                        Write-Output $Existing
                    }
                    continue
                }

                if (-not $Force) {
                    Write-Error "A Nitpick with the name '$($Nitpick.Name)' is already registered."
                    continue
                }
            }

            if ($Existing) {
                Write-Verbose "Overwriting existing Nitpick '$($Nitpick.Name)'."
            } else {
                Write-Verbose "Registering '$($Nitpick.Category)' rule '$($Nitpick.Name)'."
            }
            $Registry.Nitpicks[$Nitpick.Name] = $Nitpick

            if ($PassThru) {
                Write-Output $Nitpick
            }
        }
    }
}
