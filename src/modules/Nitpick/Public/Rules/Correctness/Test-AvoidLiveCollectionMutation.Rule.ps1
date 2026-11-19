using namespace System.Collections
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Detects mutations of a collection being enumerated by foreach.

.DESCRIPTION
    Reports direct collection-mutating calls and dictionary writes inside a
    foreach over the same receiver, its Keys/Values, or its GetEnumerator().
    Indexed writes to explicitly dictionary/list-typed parameters are included;
    ordinary array element writes and variable reassignment are not.

    Receiver matching is syntactic, not alias or control-flow analysis.
    Snapshots, transformed pipelines, and deferred nested scriptblocks are
    excluded. No automatic correction is offered because snapshot iteration
    changes behavior and allocates additional memory.
#>
function Test-AvoidLiveCollectionMutation {
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
        Description = 'Detects mutation of a live collection during foreach enumeration.'
        Severity = 'Warning'
        Explanation = 'Mutating a live dictionary or resizable collection can invalidate its enumerator and cause "Collection was modified; enumeration operation may not execute". Enumerate a snapshot, or defer mutations until after the loop.'
    }
    if ($Details) { return $Metadata }

    $Behavior = $Context.RuleBehavior
    $ShouldRecurse =
        if ($null -eq $Behavior.SearchNestedScriptBlocks) { $false }
        else { $Behavior.SearchNestedScriptBlocks }
    $OutputAs =
        if ($null -eq $Behavior.OutputType) { 'DiagnosticRecord' }
        else { $Behavior.OutputType }

    $Unwrap = {
        param($Node)
        while ($true) {
            if ($Node -is [ParenExpressionAst]) {
                $Node = $Node.Pipeline
            } elseif ($Node -is [PipelineAst] -and
                $Node.PipelineElements.Count -eq 1 -and
                -not ($Node.PSObject.Properties['Background'] -and $Node.Background) -and
                $Node.PipelineElements[0] -is [CommandExpressionAst] -and
                $Node.PipelineElements[0].Redirections.Count -eq 0
            ) {
                $Node = $Node.PipelineElements[0].Expression
            } else {
                return $Node
            }
        }
    }
    $GetReceiverPath = {
        param($Node)
        $Suffix = ''
        $Node = & $Unwrap $Node
        while ($Node -is [MemberExpressionAst] -and
            $Node -isnot [InvokeMemberExpressionAst] -and -not $Node.Static -and
            $Node.Member -is [StringConstantExpressionAst]
        ) {
            $Name = $Node.Member.Value
            $Suffix = "/$($Name.Length):$Name$Suffix"
            $Node = & $Unwrap $Node.Expression
        }
        if ($Node -is [VariableExpressionAst]) {
            $Name = $Node.VariablePath.UserPath
            return "$($Name.Length):$Name$Suffix"
        }
    }

    $ReportedOffsets = @{}
    $Loops = $ScriptBlockAst.FindAll({
        param($Node)
        $Node -is [ForEachStatementAst]
    }, $ShouldRecurse)
    foreach ($Loop in $Loops) {
        $Collection = & $Unwrap $Loop.Condition
        $DictionaryView = $false
        if ($Collection -is [MemberExpressionAst] -and -not $Collection.Static -and
            $Collection.Member -is [StringConstantExpressionAst]
        ) {
            if ($Collection -is [InvokeMemberExpressionAst]) {
                if ($Collection.Member.Value -ne 'GetEnumerator' -or
                    $Collection.Arguments.Count -ne 0
                ) { continue }
                $Collection = & $Unwrap $Collection.Expression
            } elseif ($Collection.Member.Value -in 'Keys', 'Values') {
                $DictionaryView = $true
                $Collection = & $Unwrap $Collection.Expression
            }
        }
        $ReceiverPath = & $GetReceiverPath $Collection
        if (-not $ReceiverPath) { continue }

        # A foreach variable with the receiver's name hides/rebinds that receiver.
        if ((& $GetReceiverPath $Loop.Variable) -eq $ReceiverPath) { continue }

        $Type = $null
        if ($Collection -is [VariableExpressionAst]) {
            $Scope = $Loop.Parent
            while ($Scope -and $Scope -isnot [ScriptBlockAst]) { $Scope = $Scope.Parent }
            if ($Scope -and $Scope.ParamBlock) {
                foreach ($Parameter in $Scope.ParamBlock.Parameters) {
                    if ($Parameter.Name.VariablePath.UserPath -eq $Collection.VariablePath.UserPath) {
                        $Type = $Parameter.StaticType
                        break
                    }
                }
            }
        }
        if ($Type -and $Type.Namespace -eq 'System.Collections.Concurrent') { continue }
        $IsDictionary = $DictionaryView -or
            ($Type -and [IDictionary].IsAssignableFrom($Type))
        $IsMutableList = $Type -and -not $Type.IsArray -and $Type -ne [array] -and
            [IList].IsAssignableFrom($Type)

        $Mutations = $Loop.Body.FindAll({
            param($Node)
            $Node -is [InvokeMemberExpressionAst] -or
                $Node -is [AssignmentStatementAst] -or
                ($Node -is [UnaryExpressionAst] -and
                    $Node.TokenKind.ToString() -in 'PlusPlus', 'MinusMinus', 'PostfixPlusPlus', 'PostfixMinusMinus')
        }, $false)
        foreach ($Mutation in $Mutations) {
            $Receiver = $null
            if ($Mutation -is [InvokeMemberExpressionAst]) {
                if ($Mutation.Static -or
                    $Mutation.Member -isnot [StringConstantExpressionAst] -or
                    $Mutation.Member.Value -notin 'Add', 'AddRange', 'Clear', 'Insert',
                        'InsertRange', 'Remove', 'RemoveAt', 'RemoveAll', 'RemoveRange',
                        'Reverse', 'Sort', 'Enqueue', 'Dequeue', 'Push', 'Pop'
                ) { continue }
                if ($Type -and ($Type.IsArray -or $Type -eq [array])) { continue }
                $Receiver = $Mutation.Expression
            } else {
                $Target = if ($Mutation -is [AssignmentStatementAst]) {
                    & $Unwrap $Mutation.Left
                } else {
                    & $Unwrap $Mutation.Child
                }
                if ($Target -is [IndexExpressionAst] -and ($IsDictionary -or $IsMutableList)) {
                    $Receiver = $Target.Target
                } elseif ($Target -is [MemberExpressionAst] -and
                    $Target -isnot [InvokeMemberExpressionAst] -and
                    -not $Target.Static -and $IsDictionary
                ) {
                    $Receiver = $Target.Expression
                }
            }
            if (-not $Receiver -or (& $GetReceiverPath $Receiver) -ne $ReceiverPath) { continue }
            if ($ReportedOffsets.ContainsKey($Mutation.Extent.StartOffset)) { continue }
            $ReportedOffsets[$Mutation.Extent.StartOffset] = $true

            $FilePath = if ($Mutation.Extent.File) { $Mutation.Extent.File } else { '<ScriptBlock>' }
            New-NitpickFinding `
                -RuleId $RuleId `
                -Message "This mutation of '$($Collection.Extent.Text)' may invalidate the live foreach enumerator. Enumerate a snapshot (for example, @($($Loop.Condition.Extent.Text))) or defer mutations until after the loop." `
                -ViolationExtent $Mutation.Extent `
                -Severity $Metadata.Severity `
                -ScriptPath $FilePath `
                -Explanation $Metadata.Explanation `
                -OutputAs $OutputAs
        }
    }
}
