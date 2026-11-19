using namespace System.Collections
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Detects collection equality comparisons used directly as conditions.

.DESCRIPTION
    Equality comparisons against collections return matching elements rather
    than a Boolean membership result. A falsey matching element can therefore
    make a condition false. Use -contains or -notcontains when membership is
    intended.
#>
function Test-CollectionComparisonUsedAsAPredicate {
    [CmdletBinding(DefaultParameterSetName='ScriptBlockAst')]
    [OutputType([object[]], [hashtable])]
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
    $RuleName = if ($Command.Noun) { $Command.Noun } else { $Command.Name }
    $RuleId = "Nitpick/$RuleName"
    $Metadata = [pscustomobject]@{
        Name = $RuleName
        CommandName = $Command.Name
        Category = 'Correctness'
        Description = 'Detects collection equality comparisons used as Boolean conditions.'
        Severity = 'Warning'
        Explanation = 'PowerShell collection comparisons return matching elements, not a Boolean membership result. A falsey matching element can make the condition false; use -contains or -notcontains when membership is intended.'
    }

    if ($Details) { return $Metadata }

    $Behavior = $Context.RuleBehavior
    $ShouldRecurse =
        if ($null -eq $Behavior.SearchNestedScriptBlocks) { $false }
        else { $Behavior.SearchNestedScriptBlocks }
    $OutputAs =
        if ($null -eq $Behavior.OutputType) { 'DiagnosticRecord' }
        else { $Behavior.OutputType }

    $Conditions = [System.Collections.Generic.List[Ast]]::new()
    $ControlStatements = $ScriptBlockAst.FindAll({
        param($Node)

        $Node -is [IfStatementAst] -or
            $Node -is [WhileStatementAst] -or
            $Node -is [DoWhileStatementAst] -or
            $Node -is [DoUntilStatementAst] -or
            $Node -is [ForStatementAst]
    }, $ShouldRecurse)

    foreach ($Statement in $ControlStatements) {
        if ($Statement -is [IfStatementAst]) {
            foreach ($Clause in $Statement.Clauses) {
                if ($Clause.Item1) { $Conditions.Add($Clause.Item1) }
            }
        } elseif ($Statement -is [ForStatementAst]) {
            if ($Statement.Condition) { $Conditions.Add($Statement.Condition) }
        } else {
            if ($Statement.Condition) { $Conditions.Add($Statement.Condition) }
        }
    }

    $ReportedOffsets = @{}
    foreach ($Condition in $Conditions) {
        $Comparisons = $Condition.FindAll({
            param($Node)

            $Node -is [BinaryExpressionAst] -and
                $Node.Operator.ToString() -in 'Ieq', 'Ceq', 'Ine', 'Cne'
        }, $false)

        foreach ($Comparison in $Comparisons) {
            $Left = $Comparison.Left
            $IsCollection = $Left -is [ArrayExpressionAst] -or $Left -is [ArrayLiteralAst]

            if ($Left -is [VariableExpressionAst]) {
                $Scope = $Comparison
                while ($Scope -and $Scope -isnot [ScriptBlockAst]) {
                    $Scope = $Scope.Parent
                }

                if ($Scope -and $Scope.ParamBlock) {
                    $VariableName = $Left.VariablePath.UserPath
                    $Parameter = @($Scope.ParamBlock.Parameters | Where-Object {
                        $_.Name.VariablePath.UserPath -eq $VariableName
                    } | Select-Object -First 1)

                    if ($Parameter.Count -gt 0) {
                        $Type = $Parameter[0].StaticType
                        $IsCollection = $Type -and
                            $Type -ne [string] -and
                            [System.Collections.IEnumerable].IsAssignableFrom($Type)
                    }
                }
            }

            if (-not $IsCollection) { continue }

            $OffsetKey = "$($Comparison.Extent.StartOffset):$($Comparison.Extent.EndOffset)"
            if ($ReportedOffsets.ContainsKey($OffsetKey)) { continue }
            $ReportedOffsets[$OffsetKey] = $true

            $MembershipOperator = switch ($Comparison.Operator.ToString()) {
                'Ieq' { '-contains' }
                'Ceq' { '-ccontains' }
                'Ine' { '-notcontains' }
                'Cne' { '-cnotcontains' }
            }
            $FilePath = if ($Comparison.Extent.FileName) {
                $Comparison.Extent.FileName
            } else {
                '<ScriptBlock>'
            }

            New-NitpickFinding `
                -RuleId $RuleId `
                -Message "This collection comparison filters matching elements instead of returning a Boolean. Use '$MembershipOperator' when membership is intended." `
                -ViolationExtent $Comparison.Extent `
                -Severity $Metadata.Severity `
                -ScriptPath $FilePath `
                -Explanation $Metadata.Explanation `
                -OutputAs $OutputAs
        }
    }
}
