using namespace System.Collections
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Detects variables that are assigned but never read.

.DESCRIPTION
    Reports ordinary variable assignments when the variable is not read later
    in the declaring scriptblock or one of its nested scriptblocks. Parameters,
    automatic variables, compound assignments, and variables in externally
    shared scopes are excluded because their assignment alone is not evidence
    that they are unused.

.NOTES
    So named because a friendlier name like `AvoidUnusedVars` could also imply:

    * Unused parameters
    * Unused foreach or catch bindings
    * Destructured/other declarations
    * Variables supplied by commands or external scope
    * Assignment side effects that may intentionally matter

.PARAMETER Context
    RuleBehavior.SearchNestedScriptBlocks controls traversal. The default is
    scope-local.

.EXAMPLE
    Basic usage

    Test-UseDeclaredVarsMoreThanAssignments -ScriptBlockAst {
        $Unused = 'value'
    }.Ast
#>
function Test-UseDeclaredVarsMoreThanAssignments {
    [CmdletBinding(DefaultParameterSetName='ScriptBlockAst')]
    [OutputType('NitpickFinding', 'PSCustomObject')]
    param(
        [Parameter(Mandatory,ParameterSetName='ScriptBlockAst')]
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst] $ScriptBlockAst,

        [Parameter(ParameterSetName='ScriptBlockAst')]
        [IDictionary] $Context,

        [Parameter(Mandatory,ParameterSetName='Details')]
        [switch] $Details
    )

    $Command = $PSCmdlet.MyInvocation.MyCommand
    $RuleName = $Command.Noun
    $RuleId = "Nitpick/$RuleName"
    $Metadata = [pscustomobject]@{
        Name = $RuleName
        CommandName = $Command.Name
        Category = 'Quality'
        Description = 'Detects variables that are assigned but never read.'
        Severity = 'Warning'
        Explanation = 'A variable assigned without a read can indicate dead state, a misspelled reference, or a partially completed change.'
    }

    if ($Details) {
        Write-Output $Metadata
        return
    }

    $Behavior = $Context.RuleBehavior
    $ShouldRecurse =
        if ($null -eq $Behavior.SearchNestedScriptBlocks) { $false }
        else { $Behavior.SearchNestedScriptBlocks }

    $AutomaticVariableNames = @{
        '_' = $true
        'args' = $true
        'error' = $true
        'home' = $true
        'host' = $true
        'input' = $true
        'lastexitcode' = $true
        'matches' = $true
        'myinvocation' = $true
        'nestedpromptlevel' = $true
        'null' = $true
        'pid' = $true
        'profile' = $true
        'psboundparameters' = $true
        'pscmdlet' = $true
        'pscommandpath' = $true
        'psedition' = $true
        'pshome' = $true
        'psitem' = $true
        'psscriptroot' = $true
        'pssessionapplicationname' = $true
        'pssessionconfigurationname' = $true
        'pssessionoption' = $true
        'psuiculture' = $true
        'psversiontable' = $true
        'pwd' = $true
        'shellid' = $true
        'stacktrace' = $true
        'this' = $true
    }

    $GetScope = {
        param($Node)

        while ($null -ne $Node -and $Node -isnot [ScriptBlockAst]) {
            $Node = $Node.Parent
        }

        Write-Output -InputObject $Node
    }

    $GetVariableName = {
        param($Variable)

        $Name = [string] $Variable.VariablePath.UserPath
        if ($Variable.VariablePath.IsLocal -or
            $Variable.VariablePath.IsPrivate
        ) {
            $Name = $Name.Substring($Name.IndexOf(':') + 1)
        }

        Write-Output $Name
    }

    $Assignments = $ScriptBlockAst.FindAll({
        param($Node)

        $Node -is [AssignmentStatementAst] -and
            $Node.Operator -eq [TokenKind]::Equals -and
            $Node.Left -is [VariableExpressionAst]
    }, $ShouldRecurse)

    $ReportedAssignments = @{}

    foreach ($Assignment in $Assignments) {
        $Variable = $Assignment.Left
        $VariablePath = $Variable.VariablePath
        if (-not $VariablePath.IsVariable -or
            $VariablePath.IsGlobal -or
            $VariablePath.IsScript
        ) {
            continue
        }

        $VariableName = & $GetVariableName $Variable
        if ($AutomaticVariableNames.ContainsKey($VariableName)) { continue }

        $Scope = & $GetScope $Variable
        $Parameters = @(
            if ($null -ne $Scope.ParamBlock) {
                $Scope.ParamBlock.Parameters |
                    ForEach-Object { & $GetVariableName $_.Name }
            }
        )
        if ($VariableName -iin $Parameters) { continue }

        $AssignmentKey = "$($Scope.Extent.StartOffset):$VariableName"
        if ($ReportedAssignments.ContainsKey($AssignmentKey)) { continue }
        $ReportedAssignments[$AssignmentKey] = $true

        $HasUse = $false
        $Occurrences = $Scope.FindAll({
            param($Node)

            $Node -is [VariableExpressionAst] -and
                ($Node.VariablePath.IsVariable -or $Node.VariablePath.IsDriveQualified) -and
                ( (& $GetVariableName $Node) -ieq $VariableName )
        }, $true)

        foreach ($Occurrence in $Occurrences) {
            $Parent = $Occurrence.Parent
            $IsSimpleAssignmentTarget =
                $Parent -is [AssignmentStatementAst] -and
                $Parent.Operator -eq [TokenKind]::Equals -and
                [object]::ReferenceEquals($Parent.Left, $Occurrence)

            if (-not $IsSimpleAssignmentTarget) {
                $HasUse = $true
                break
            }
        }

        if ($HasUse) { continue }

        $FilePath = if ($Variable.Extent.File) {
            $Variable.Extent.File
        } else {
            '<ScriptBlock>'
        }

        New-NitpickFinding `
            -RuleId $RuleId `
            -Message "Variable '$VariableName' is assigned but never used." `
            -ViolationExtent $Variable.Extent `
            -Severity $Metadata.Severity `
            -ScriptPath $FilePath `
            -Explanation $Metadata.Explanation
    }
}
