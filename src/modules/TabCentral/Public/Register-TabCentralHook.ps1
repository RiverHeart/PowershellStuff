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
    [CmdletBinding()]
    [OutputType([void], [pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({
            $_ -is [string] -or
            $_ -is [scriptblock] -or
            $_ -is [FunctionInfo] -or
            $_ -is [CmdletInfo]
        })]
        [object] $Callable,

        [Parameter(Mandatory)]
        [ValidateSet('Completer', 'Modifier')]
        [string] $Type,

        [Parameter(HelpMessage='The name of the hook. Mandatory only when using a scriptblock')]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(HelpMessage='The source of the hook. Mandatory only when using a scriptblock')]
        [ValidateNotNullOrEmpty()]
        [string] $Source,

        [switch] $Force,
        [switch] $PassThru
    )

    process {
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
