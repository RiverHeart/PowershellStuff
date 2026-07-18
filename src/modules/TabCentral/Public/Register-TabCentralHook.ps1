<#
.SYNOPSIS
    Registers a custom tab completer script block to be used during tab expansion.

.DESCRIPTION
    This function allows you to register a custom tab completer script block that will be invoked during
    tab expansion.

.NOTES
    Tab completers must return CommandCompletion objects.

.EXAMPLE
    Register-TabCentralHook -Name 'MyCompleter' -Type 'Completer' -ScriptBlock {
        param($CommandName, $ParameterName, $WordToComplete, $CommandAst, $FakeBoundParameters)
        # Custom completion logic here
    }

.EXAMPLE
    Get-WPFTabCentralHook | Register-TabCentralHook -Force
#>
function Register-TabCentralHook {
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
        [ValidateSet('Completer', 'Modifier')]
        [string] $Type,

        [Parameter(HelpMessage='The name of the hook. Mandatory only when using a scriptblock',ParameterSetName='Default')]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(HelpMessage='The source of the hook. Mandatory only when using a scriptblock',ParameterSetName='Default')]
        [ValidateNotNullOrEmpty()]
        [string] $Source,

        [Parameter(Mandatory,ParameterSetName='Module')]
        [ValidateScript({
            $_ -is [string] -or
            $_ -is [System.Management.Automation.PSModuleInfo]
        })]
        [object] $Module,

        [Parameter(ParameterSetName='Module')]
        [version] $Version,

        [switch] $Force,
        [switch] $PassThru
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Module') {
            $ResolvedModule = $null

            if ($Module -is [string]) {
                $LoadedMatches = @(
                    Get-Module -Name $Module -All | Sort-Object Version -Descending
                )
                if ($Version) {
                    $LoadedMatches = @($LoadedMatches | Where-Object { $_.Version -eq $Version })
                }

                if ($LoadedMatches.Count -gt 0) {
                    $ResolvedModule = $LoadedMatches[0]
                } else {
                    $AvailableMatches = @(
                        Get-Module -ListAvailable -Name $Module | Sort-Object Version -Descending
                    )
                    if ($Version) {
                        $AvailableMatches = @($AvailableMatches | Where-Object { $_.Version -eq $Version })
                    }

                    if ($AvailableMatches.Count -eq 0) {
                        if ($Version) {
                            Write-Error "Module '$Module' with version '$Version' was not found." -Category ObjectNotFound
                        } else {
                            Write-Error "Module '$Module' was not found." -Category ObjectNotFound
                        }
                        return
                    }

                    $ResolvedModule = $AvailableMatches[0]

                    if ($AvailableMatches.Count -gt 1) {
                        Write-Verbose (
                            "Multiple module versions found for '$Module'. " +
                            "Using '$($ResolvedModule.Name)' version '$($ResolvedModule.Version)' at '$($ResolvedModule.Path)'."
                        )
                    }
                }
            } else {
                $ResolvedModule = $Module

                if ($Version -and $ResolvedModule.Version -ne $Version) {
                    Write-Error (
                        "Provided module '$($ResolvedModule.Name)' version '$($ResolvedModule.Version)' " +
                        "does not match requested version '$Version'."
                    ) -Category InvalidArgument
                    return
                }
            }

            if (-not (Get-Module -Name $ResolvedModule.Name -All | Where-Object { $_.Path -eq $ResolvedModule.Path })) {
                if (-not $ResolvedModule.Path) {
                    Write-Error "Module '$($ResolvedModule.Name)' is not loaded and has no path to import from." -Category InvalidArgument
                    return
                }

                $ImportParams = @{
                    Name = $ResolvedModule.Path
                    ErrorAction = 'Stop'
                }
                $null = Import-Module @ImportParams
                $ResolvedModule = Get-Module -Name $ResolvedModule.Name | Sort-Object Version -Descending | Select-Object -First 1
            }

            $TabExpansion = $ResolvedModule.PrivateData.TabExpansion

            $Completers = @($TabExpansion.Completers)
            $Modifiers = @($TabExpansion.Modifiers)

            if ($Completers.Count -eq 0 -and $Modifiers.Count -eq 0) {
                Write-Error "No tab completers or modifiers found in module '$($ResolvedModule.Name)'." -Category InvalidData
                return
            }

            foreach($Completer in $Completers) {
                $ChildParams = @{
                    Name = $Completer
                    Type = 'Completer'
                    Callable = $Completer
                    Force = $Force
                    PassThru = $PassThru
                }
                Register-TabCentralHook @ChildParams
            }

            foreach($Modifier in $Modifiers) {
                $ChildParams = @{
                    Name = $Modifier
                    Type = 'Modifier'
                    Callable = $Modifier
                    Force = $Force
                    PassThru = $PassThru
                }
                Register-TabCentralHook @ChildParams
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
