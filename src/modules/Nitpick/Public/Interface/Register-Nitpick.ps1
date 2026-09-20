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
        [string] $Type,

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

            $LintRules = $ResolvedModule.PrivateData.LintRules

            if ($LintRules.Count -eq 0) {
                Write-Error "No lint rules found in module '$($ResolvedModule.Name)'." -Category InvalidData
                return
            }

            foreach ($LintRule in $LintRules) {
                $ChildParams = @{
                    Name = $LintRule
                    Type = 'LintRule'
                    Callable = $LintRule
                    Force = $Force
                    PassThru = $PassThru
                }
                Register-Nitpick @ChildParams
            }

            return
        }

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
