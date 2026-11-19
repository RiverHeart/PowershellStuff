using namespace System.Collections
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Detects captured member projection on known arrays that may be empty.

.DESCRIPTION
    Reports direct @($Items.Property) captures when the receiver is an array
    expression, an array cast, or an array-typed parameter in the current lexical
    scope. An empty array falls back to member lookup on the array itself, which
    can contribute a null item instead of zero projected items.

    Actual array properties, methods, dynamic members, pipelines, and unknown
    receiver types are excluded. No runtime values or cardinality are inferred.
    Findings are diagnostic-only: projection can differ from collection property
    access, and explicit null property values must not be silently removed.

.PARAMETER Context
    RuleBehavior.SearchNestedScriptBlocks controls traversal; OutputType selects
    NitpickFinding or DiagnosticRecord. Defaults are scope-local diagnostics.

.EXAMPLE
    Test-EmptyCollectionMemberAccess -ScriptBlockAst {
        param([object[]] $Items)
        $Names = @($Items.Name)
    }.Ast
#>
function Test-EmptyCollectionMemberAccess {
    [CmdletBinding(DefaultParameterSetName='ScriptBlockAst')]
    [OutputType('NitpickFinding', 'DiagnosticRecord', 'PSCustomObject')]
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
        Category = 'Correctness'
        Description = 'Detects captured member projection on arrays that may be empty.'
        Severity = 'Warning'
        Explanation = 'Member access on an empty array can produce a null item rather than zero projected items. Use explicit pipeline projection when per-item access is intended; preserve explicit null property values unless filtering is intentional.'
    }
    if ($Details) { return $Metadata }

    $Behavior = $Context.RuleBehavior
    $ShouldRecurse =
        if ($null -eq $Behavior.SearchNestedScriptBlocks) { $false }
        else { $Behavior.SearchNestedScriptBlocks }
    $OutputAs =
        if ($null -eq $Behavior.OutputType) { 'DiagnosticRecord' }
        else { $Behavior.OutputType }

    $Arrays = $ScriptBlockAst.FindAll({
        param($Node)
        $Node -is [ArrayExpressionAst]
    }, $ShouldRecurse)

    foreach ($Array in $Arrays) {
        if ($Array.SubExpression.Statements.Count -ne 1 -or
            $Array.SubExpression.Traps.Count -gt 0
        ) { continue }

        $Current = $Array.SubExpression.Statements[0]
        while ($Current -is [PipelineAst]) {
            if ($Current.PipelineElements.Count -ne 1 -or
                ($Current.PSObject.Properties['Background'] -and $Current.Background)
            ) { break }
            $Element = $Current.PipelineElements[0]
            if ($Element -isnot [CommandExpressionAst] -or $Element.Redirections.Count -gt 0) { break }
            $Current = $Element.Expression
            if ($Current -is [ParenExpressionAst]) { $Current = $Current.Pipeline }
        }

        if ($Current -isnot [MemberExpressionAst] -or
            $Current -is [InvokeMemberExpressionAst] -or $Current.Static -or
            $Current.Member -isnot [StringConstantExpressionAst]
        ) { continue }

        $Member = $Current.Member.Value
        $Receiver = $Current.Expression
        # Parentheses retain the receiver's array type, but pipelines do not.
        while ($Receiver -is [ParenExpressionAst] -and
            $Receiver.Pipeline -is [PipelineAst] -and
            $Receiver.Pipeline.PipelineElements.Count -eq 1 -and
            $Receiver.Pipeline.PipelineElements[0] -is [CommandExpressionAst] -and
            $Receiver.Pipeline.PipelineElements[0].Redirections.Count -eq 0 -and
            -not ($Receiver.Pipeline.PSObject.Properties['Background'] -and $Receiver.Pipeline.Background)
        ) {
            $Receiver = $Receiver.Pipeline.PipelineElements[0].Expression
        }

        $Type = $null
        if ($Receiver -is [ArrayExpressionAst] -or $Receiver -is [ArrayLiteralAst]) {
            $Type = [object[]]
        } elseif ($Receiver -is [ConvertExpressionAst]) {
            $Type = $Receiver.Type.TypeName.GetReflectionType()
        } elseif ($Receiver -is [VariableExpressionAst] -and
            $Receiver.VariablePath.IsUnqualified
        ) {
            $Scope = $Current.Parent
            while ($Scope -and $Scope -isnot [ScriptBlockAst]) { $Scope = $Scope.Parent }
            if ($Scope -and $Scope.ParamBlock) {
                foreach ($Parameter in $Scope.ParamBlock.Parameters) {
                    if ($Parameter.Name.VariablePath.UserPath -eq $Receiver.VariablePath.UserPath) {
                        $Type = $Parameter.StaticType
                        break
                    }
                }
            }
        }
        if (-not $Type -or ($Type -ne [array] -and -not $Type.IsArray)) { continue }

        $OwnProperties = @($Type.GetProperties().Name)
        foreach ($Interface in $Type.GetInterfaces()) {
            $OwnProperties += $Interface.GetProperties().Name
        }
        if ($Member -in $OwnProperties -or
            $Member -in 'Count', 'Length', 'LongLength', 'Rank', 'SyncRoot',
                'IsReadOnly', 'IsFixedSize', 'IsSynchronized',
                'PSObject', 'PSBase', 'PSAdapted', 'PSExtended', 'PSTypeNames'
        ) { continue }

        $FilePath = if ($Array.Extent.File) { $Array.Extent.File } else { '<ScriptBlock>' }
        New-NitpickFinding `
            -RuleId $RuleId `
            -Message "If this array is empty, member access '$Member' can contribute one null item instead of zero projected items. Use an explicit pipeline with ForEach-Object { `$_.$($Current.Member.Extent.Text) } when per-item projection is intended; do not filter legitimate null property values unless intended." `
            -ViolationExtent $Array.Extent `
            -Severity $Metadata.Severity `
            -ScriptPath $FilePath `
            -Explanation $Metadata.Explanation `
            -OutputAs $OutputAs
    }
}
