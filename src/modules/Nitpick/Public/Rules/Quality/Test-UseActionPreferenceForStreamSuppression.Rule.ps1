using namespace System.Collections
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Detects warning or error streams redirected to $null on PowerShell commands.

.DESCRIPTION
    PowerShell commands that support common parameters can suppress warning and
    error output with -WarningAction SilentlyContinue or
    -ErrorAction SilentlyContinue. Redirecting those streams to $null is still
    observable by hosts and test instrumentation.

    This rule is diagnostic-only because the replacement action parameter can
    change command behavior, and tests may prefer to mock Write-Warning or
    Write-Error when their invocation is the behavior under test.
    Standalone native findings use
    Nitpick/UseActionPreferenceForStreamSuppression. Coordinated execution
    replaces that identity with the executing descriptor's ID.

.PARAMETER ScriptBlockAst
    The parsed target to inspect.

.PARAMETER Context
    Optional invocation data. RuleBehavior.SearchNestedScriptBlocks controls traversal.
    Without this setting, traversal is scope-local.

.PARAMETER Details
    Returns rule metadata instead of findings.

.EXAMPLE
    Test-UseActionPreferenceForStreamSuppression -ScriptBlockAst (
        [scriptblock]::Create("Write-Warning 'message' 3>`$null").Ast
    )
#>
function Test-UseActionPreferenceForStreamSuppression {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlockAst')]
    [OutputType('NitpickFinding', 'PSCustomObject')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ScriptBlockAst')]
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst] $ScriptBlockAst,

        [Parameter(ParameterSetName = 'ScriptBlockAst')]
        [IDictionary] $Context,

        [Parameter(Mandatory, ParameterSetName = 'Details')]
        [switch] $Details
    )

    $Command = $PSCmdlet.MyInvocation.MyCommand
    $RuleName = if ($Command.Noun) { $Command.Noun } else { $Command.Name }
    $RuleId = "Nitpick/$RuleName"
    $Metadata = [pscustomobject]@{
        Name = $RuleName
        CommandName = $Command.Name
        Category = 'Quality'
        Description = 'Detects warning or error streams redirected to $null when an action preference is available.'
        Severity = 'Information'
        Explanation = (
            'WarningAction and ErrorAction suppress the stream at the command boundary, ' +
            'while redirection can remain observable to hosts and test instrumentation.'
        )
    }

    if ($Details) { return $Metadata }

    $Behavior = $Context.RuleBehavior
    $ShouldRecurse =
        if ($null -eq $Behavior.SearchNestedScriptBlocks) { $false }
        else { $Behavior.SearchNestedScriptBlocks }

    $Redirections = $ScriptBlockAst.FindAll({
        param($Node)

        $Node -is [FileRedirectionAst] -and
            $Node.FromStream -in 'Error', 'Warning' -and
            $Node.Location -is [VariableExpressionAst] -and
            $Node.Location.VariablePath.UserPath -eq 'null'
    }, $ShouldRecurse)

    $CommandActionSupport = @{}

    foreach ($Redirection in $Redirections) {
        $ParentCommand = $Redirection.Parent
        if ($ParentCommand -isnot [CommandAst] -or
            $ParentCommand.InvocationOperator -ne [TokenKind]::Unknown
        ) {
            continue
        }

        $CommandName = $ParentCommand.GetCommandName()
        if ([string]::IsNullOrWhiteSpace($CommandName)) { continue }

        $ActionParameter = if ($Redirection.FromStream -eq 'Warning') {
            'WarningAction'
        } else {
            'ErrorAction'
        }

        $CacheKey = "$CommandName`0$ActionParameter"

        if (-not $CommandActionSupport.ContainsKey($CacheKey)) {
            $SupportsAction = $false
            foreach ($ResolvedCommand in @(Get-Command -Name $CommandName -ErrorAction SilentlyContinue)) {
                while ($ResolvedCommand -is [System.Management.Automation.AliasInfo] -and
                    $ResolvedCommand.ResolvedCommand
                ) {
                    $ResolvedCommand = $ResolvedCommand.ResolvedCommand
                }

                if ($null -ne $ResolvedCommand.Parameters -and
                    $ResolvedCommand.Parameters.ContainsKey($ActionParameter)
                ) {
                    $SupportsAction = $true
                    break
                }
            }

            $CommandActionSupport[$CacheKey] = $SupportsAction
        }

        if (-not $CommandActionSupport[$CacheKey]) { continue }

        $StreamNumber = if ($Redirection.FromStream -eq 'Warning') { 3 } else { 2 }
        $FilePath = if ($Redirection.Extent.File) {
            $Redirection.Extent.File
        } else {
            '<ScriptBlock>'
        }

        $WriterName = if ($ActionParameter -eq 'WarningAction') {
            'Write-Warning'
        } else {
            'Write-Error'
        }

        $TestingHint = if ($CommandName -ieq $WriterName) {
            " When testing its invocation, mock $WriterName instead."
        } else {
            ''
        }

        New-NitpickFinding `
            -RuleId $RuleId `
            -Message ("Prefer '-{0} SilentlyContinue' over '{1}>`$null' for PowerShell command '{2}'.{3}" -f
                $ActionParameter, $StreamNumber, $CommandName, $TestingHint) `
            -ViolationExtent $Redirection.Extent `
            -Severity $Metadata.Severity `
            -ScriptPath $FilePath `
            -Explanation $Metadata.Explanation
    }
}
