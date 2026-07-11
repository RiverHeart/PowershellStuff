<#
.SYNOPSIS
    Registers a custom tab completer script block to be used during tab expansion.

.DESCRIPTION
    This function allows you to register a custom tab completer script block that will be invoked during
    tab expansion. The registered script block will be called with the same parameters as the
    Complete-WPFThis function, allowing you to provide custom completions for specific scenarios.

.NOTES
    Tab completers must return CommandCompletion objects. See the Complete-WPFThis function for more details.

.EXAMPLE
    Register-TabExpansionHook -Name 'MyCompleter' -Type 'Completer' -ScriptBlock {
        param($CommandName, $ParameterName, $WordToComplete, $CommandAst, $FakeBoundParameters)
        # Custom completion logic here
    }
#>
function Register-TabExpansionHook {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    param (
        [Parameter(Mandatory,ParameterSetName='ScriptBlock')]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory,ParameterSetName='ScriptBlock')]
        [ValidateNotNullOrEmpty()]
        [ScriptBlock] $ScriptBlock,

        # This can be a CmdletInfo or a FunctionInfo object.
        [Parameter(Mandatory,ParameterSetName='Function')]
        [ValidateScript({ $_ -is [System.Management.Automation.FunctionInfo] -or $_ -is [System.Management.Automation.CmdletInfo] })]
        [Object] $Function,

        [Parameter(Mandatory,ParameterSetName='FunctionName')]
        [ValidateNotNullOrEmpty()]
        [string] $FunctionName,

        [Parameter(Mandatory)]
        [ValidateSet('Completer', 'Modifier')]
        [string] $Type,

        [switch] $Force
    )

    $Registry = Get-WPFTabExpansionRegistry

    $TargetRegistry = switch ($Type) {
        'Completer' { $Registry.TabCompleters }
        'Modifier'  { $Registry.ResultModifiers }
        default     { throw "Invalid type '$Type'. Must be 'Completer' or 'Modifier'." }
    }

    if ($PSCmdlet.ParameterSetName -eq 'Function') {
        $Name = $Function.Name
        $ScriptBlock = $Function.ScriptBlock
    } elseif ($PSCmdlet.ParameterSetName -eq 'FunctionName') {
        try {
            $Function = Get-Command $FunctionName -CommandType Function -ErrorAction Stop
            $Name = $Function.Name
            $ScriptBlock = $Function.ScriptBlock
        } catch {
            Write-Warning "Function '$FunctionName' not found."
            return
        }
    }

    if ($TargetRegistry.ContainsKey($Name)) {
        if (-not $Force) {
            Write-Error "The provided script block is already registered as a TabExpansion hook of type '$Type'."
            return
        }
    }

    Write-Verbose "Registering TabExpansion hook '$Name' of type '$Type'."
    $TargetRegistry[$Name] = $ScriptBlock
}
