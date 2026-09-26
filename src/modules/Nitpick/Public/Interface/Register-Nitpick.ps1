<#
.SYNOPSIS

#>
function Register-Nitpick {
    [CmdletBinding(DefaultParameterSetName='Default')]
    [OutputType([void], [pscustomobject])]
    param (
        [Parameter(Mandatory,ParameterSetName='Default')]
        [ValidateScript({
            $_ -is [string] -or
            $_ -is [scriptblock] -or
            $_ -is [FunctionInfo] -or
            $_ -is [CmdletInfo]
        })]
        [object] $Callable,

        [Parameter(Mandatory,ParameterSetName='Default')]
        [ValidateSet('Style', 'Quality', 'Security', 'Performance', 'Maintainability', 'Other')]
        [string] $Category,

        [Parameter(HelpMessage='Mandatory only when using a scriptblock',ParameterSetName='Default')]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(HelpMessage='Mandatory only when using a scriptblock',ParameterSetName='Default')]
        [ValidateNotNullOrEmpty()]
        [string] $Source,

        [Parameter(Mandatory,ParameterSetName='Module')]
        [ValidateNotNullOrEmpty()]
        [string] $Module,

        [Parameter(ParameterSetName='Module')]
        [ValidateNotNullOrEmpty()]
        [string] $RequiredVersion,

        [switch] $Force,
        [switch] $PassThru
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Module') {
            $ResolveParams = @{
                Name = if ($Module -is [string]) { $Module } else { $Module.Name }
            }
            if ($RequiredVersion) { $ResolveParams.RequiredVersion = $RequiredVersion }

            $ResolvedModule = Resolve-Module @ResolveParams
            if (-not $ResolvedModule) {
                Write-Error "Module '$($Module)' could not be resolved." -Category ObjectNotFound
                return
            }

            if (-not $ResolvedModule.PrivateData.Linting) {
                Write-Error "No linting information found in module '$($ResolvedModule.Name)'." -Category InvalidData
                return
            }

            # Modules may separate their linting rules into submodules to avoid polluting
            # the main module namespace.
            if ($ResolvedModule.PrivateData.Linting.RuleModules) {
                foreach ($RuleModule in $ResolvedModule.PrivateData.Linting.RuleModules) {
                    Import-Module "$($ResolvedModule.ModuleBase)/$RuleModule" -Force
                }
            }

            $LintRules = $ResolvedModule.PrivateData.Linting.Rules

            if ($LintRules.Count -eq 0) {
                Write-Error "No lint rules found in module '$($ResolvedModule.Name)'." -Category InvalidData
                return
            }

            foreach ($LintRule in $LintRules) {
                $RegistrationParams = @{
                    Name = $LintRule
                    Category = $Category
                    Callable = $LintRule
                    Force = $Force
                    PassThru = $PassThru
                }
                Register-Nitpick @RegistrationParams
            }

            return
        }  # End of 'Module' parameter set check

        $NitpickParams = @{} + $PSBoundParameters
        $null = $NitpickParams.Remove('PassThru')
        $null = $NitpickParams.Remove('Force')

        $Nitpick = New-Nitpick @NitpickParams
        $Registry = Get-NitpickRegistry

        if ($Registry.Nitpicks.ContainsKey($Nitpick.Name)) {
            if (-not $Force) {
                Write-Error "Nitpick '$($Nitpick.Name)' is already registered."
                return
            }
        }

        Write-Verbose "Registering nitpick '$($Nitpick.Name)' as '$($Nitpick.Type)'."
        $Registry.Nitpicks[$Nitpick.Name] = $Nitpick

        if ($PassThru) {
            return $Nitpick
        }
    }
}
