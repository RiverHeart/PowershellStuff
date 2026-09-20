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

        $HookParams = $PSBoundParameters
        $null = $HookParams.Remove('PassThru')
        $null = $HookParams.Remove('Force')

        $Hook = New-TabCentralHook @HookParams
        $Registry = Get-TabCentralRegistry
        $TargetRegistry = switch ($Hook.Type) {
            'Completer' { $Registry.TabCompleters }
            'Modifier' { $Registry.ResultModifiers }
        }

        if ($TargetRegistry.ContainsKey($Hook.Name)) {
            if (-not $Force) {
                Write-Error "Hook '$($Hook.Name)' already registered as '$($Hook.Type)'."
                return
            }
        }

        Write-Verbose "Registering hook '$($Hook.Name)' as '$($Hook.Type)'."
        $TargetRegistry[$Hook.Name] = $Hook

        if ($PassThru) {
            return $Hook
        }
    }
}
