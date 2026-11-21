using namespace System.Collections
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Detects namespace-dependent types in isolated execution contexts.

.DESCRIPTION
    Reports shortened type names whose resolution depends on outer using
    namespace statements when code is evaluated outside its original parse
    context. The MVP recognizes dynamicparam blocks, direct or simply assigned
    scriptblocks passed to ToString(), AddScript(), or [scriptblock]::Create(),
    plus constant string arguments to AddScript() and [scriptblock]::Create().

    Dynamic script construction, interprocedural variable tracking, and
    automatic corrections are intentionally outside the rule's scope.

.PARAMETER Context
    RuleBehavior.SearchNestedScriptBlocks controls traversal. The default is
    scope-local.

.EXAMPLE
    Test-PossibleTypeResolutionFailure -ScriptBlockAst {
        using namespace System.Collections
        $Block = { param([IDictionary] $Values) }
        $PowerShell.AddScript($Block.ToString())
    }.Ast
#>
function Test-PossibleTypeResolutionFailure {
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
        Category = 'Correctness'
        Description = 'Detects namespace-dependent types in isolated execution contexts.'
        Severity = 'Warning'
        Explanation = 'Isolated parsing or delayed parameter evaluation can omit outer using namespace statements, causing shortened type names to fail even when they resolve in the original parse context.'
    }

    if ($Details) {
        Write-Output $Metadata
        return
    }

    $RootScriptBlockAst = $ScriptBlockAst
    $Ancestor = $ScriptBlockAst.Parent
    while ($null -ne $Ancestor) {
        if ($Ancestor -is [ScriptBlockAst]) {
            $RootScriptBlockAst = $Ancestor
        }
        $Ancestor = $Ancestor.Parent
    }

    $NamespaceNames = @(
        $RootScriptBlockAst.UsingStatements |
            Where-Object { $_.UsingStatementKind -eq [UsingStatementKind]::Namespace } |
            ForEach-Object { [string] $_.Name.Value }
    )
    if ($NamespaceNames.Count -eq 0) { return }

    $TypeAcceleratorType = [PSObject].Assembly.GetType(
        'System.Management.Automation.TypeAccelerators'
    )
    $TypeAccelerators = $TypeAcceleratorType.
        GetProperty(
            'Get',
            [System.Reflection.BindingFlags] 'Public, Static'
        ).
        GetValue($null, $null)

    $Behavior = $Context.RuleBehavior
    $ShouldRecurse =
        if ($null -eq $Behavior.SearchNestedScriptBlocks) { $false }
        else { $Behavior.SearchNestedScriptBlocks }

    $UnwrapExpression = {
        param($Node)
        while ($true) {
            if ($Node -is [ParenExpressionAst]) {
                $Node = $Node.Pipeline
                continue
            }

            if ($Node -is [CommandExpressionAst] -and
                $Node.Redirections.Count -eq 0
            ) {
                $Node = $Node.Expression
                continue
            }

            if ($Node -is [PipelineAst] -and
                $Node.PipelineElements.Count -eq 1 -and
                $Node.PipelineElements[0] -is [CommandExpressionAst] -and
                $Node.PipelineElements[0].Redirections.Count -eq 0
            ) {
                $Node = $Node.PipelineElements[0].Expression
                continue
            }

            Write-Output $Node
            return
        }
    }

    $ResolveScriptBlock = {
        param($Node, $UseAst)
        $Node = & $UnwrapExpression $Node

        if ($Node -is [ScriptBlockExpressionAst]) {
            Write-Output -InputObject (, $Node.ScriptBlock)
            return
        }

        if ($Node -isnot [VariableExpressionAst]) { return }

        $Scope = $UseAst
        while ($null -ne $Scope -and $Scope -isnot [ScriptBlockAst]) {
            $Scope = $Scope.Parent
        }
        if ($null -eq $Scope) { return }

        $VariableName = $Node.VariablePath.UserPath
        $Assignments = @(
            $Scope.FindAll({
                param($Candidate)
                if ($Candidate -isnot [AssignmentStatementAst]) { return $false }
                $Left = & $UnwrapExpression $Candidate.Left
                $Left -is [VariableExpressionAst] -and
                    $Left.VariablePath.UserPath -eq $VariableName -and
                    $Candidate.Extent.StartOffset -lt $UseAst.Extent.StartOffset
            }, $false)
        )
        if ($Assignments.Count -ne 1) { return }

        $Value = & $UnwrapExpression $Assignments[0].Right
        if ($Value -isnot [ScriptBlockExpressionAst]) { return }

        Write-Output -InputObject (, $Value.ScriptBlock)
    }

    $TestTypeName = {
        param($TypeName)

        foreach ($GenericArgument in $TypeName.GenericArguments) {
            if (& $TestTypeName $GenericArgument) { return $true }
        }

        $SourceName = [string] $TypeName.FullName
        if ([string]::IsNullOrWhiteSpace($SourceName) -or
            $SourceName.Contains('.')
        ) {
            return $false
        }

        $AcceleratorName = $SourceName
        while ($AcceleratorName.EndsWith('[]')) {
            $AcceleratorName = $AcceleratorName.Substring(
                0,
                $AcceleratorName.Length - 2
            )
        }
        if ($TypeAccelerators.ContainsKey($AcceleratorName)) {
            return $false
        }

        $ResolvedType = $TypeName.GetReflectionType()
        if ($null -eq $ResolvedType -or
            [string]::IsNullOrWhiteSpace($ResolvedType.Namespace)
        ) {
            return $false
        }

        return $ResolvedType.Namespace -in $NamespaceNames
    }

    $GetDependentTypeNodes = {
        param($Block)
        $Block.FindAll({
            param($Node)
            if ($Node -isnot [TypeExpressionAst] -and
                $Node -isnot [TypeConstraintAst]
            ) {
                return $false
            }

            & $TestTypeName $Node.TypeName
        }, $true)
    }

    $SerializedBlocks = @(
        $ScriptBlockAst.FindAll({
            param($Node)
            if ($Node -isnot [InvokeMemberExpressionAst]) { return $false }
            $MemberName = $Node.Member.Value
            if ($MemberName -eq 'ToString') { return $true }
            if ($MemberName -eq 'AddScript') { return $Node.Arguments.Count -gt 0 }
            if ($MemberName -ne 'Create' -or
                -not $Node.Static -or
                $Node.Expression -isnot [TypeExpressionAst] -or
                $Node.Arguments.Count -eq 0
            ) {
                return $false
            }

            $Node.Expression.TypeName.FullName -in @(
                'scriptblock',
                'System.Management.Automation.ScriptBlock'
            )
        }, $ShouldRecurse)
    )

    $ReportedTypeOffsets = @{}
    $Functions = @(
        $ScriptBlockAst.FindAll({
            param($Node)
            $Node -is [FunctionDefinitionAst]
        }, $ShouldRecurse)
    )
    $FunctionsByName = @{}
    foreach ($Function in $ScriptBlockAst.FindAll({
        param($Node)
        $Node -is [FunctionDefinitionAst]
    }, $true)) {
        if (-not $FunctionsByName.ContainsKey($Function.Name)) {
            $FunctionsByName[$Function.Name] = $Function
        }
    }

    foreach ($Function in $Functions) {
        $DynamicParamBlock = $Function.Body.DynamicParamBlock
        if ($null -eq $DynamicParamBlock) { continue }

        $DynamicCommands = @(
            $DynamicParamBlock.FindAll({
                param($Node)
                $Node -is [CommandAst]
            }, $true)
        )
        foreach ($CommandAst in $DynamicCommands) {
            $CommandName = $CommandAst.GetCommandName()
            if ([string]::IsNullOrWhiteSpace($CommandName) -or
                -not $FunctionsByName.ContainsKey($CommandName)
            ) {
                continue
            }

            $CalledFunction = $FunctionsByName[$CommandName]
            if ($null -eq $CalledFunction.Body.ParamBlock) { continue }

            foreach ($Attribute in $CalledFunction.Body.ParamBlock.Attributes) {
                if ($Attribute.TypeName.Name -ne 'OutputType') { continue }

                foreach ($TypeNode in $Attribute.PositionalArguments) {
                    if ($TypeNode -isnot [TypeExpressionAst] -or
                        -not (& $TestTypeName $TypeNode.TypeName)
                    ) {
                        continue
                    }

                    $Offset = $TypeNode.Extent.StartOffset
                    if ($ReportedTypeOffsets.ContainsKey($Offset)) { continue }
                    $ReportedTypeOffsets[$Offset] = $true

                    $FilePath = if ($TypeNode.Extent.File) {
                        $TypeNode.Extent.File
                    } else {
                        '<ScriptBlock>'
                    }
                    New-NitpickFinding `
                        -RuleId $RuleId `
                        -Message "The OutputType '$($TypeNode.Extent.Text)' depends on an outer using namespace statement, but its command is called while resolving dynamic parameters. Use a type name that remains resolvable while command metadata is evaluated." `
                        -ViolationExtent $TypeNode.Extent `
                        -Severity $Metadata.Severity `
                        -ScriptPath $FilePath `
                        -Explanation $Metadata.Explanation
                }
            }
        }

        foreach ($TypeNode in @(& $GetDependentTypeNodes $DynamicParamBlock)) {
            $Offset = $TypeNode.Extent.StartOffset
            if ($ReportedTypeOffsets.ContainsKey($Offset)) { continue }
            $ReportedTypeOffsets[$Offset] = $true

            $FilePath = if ($TypeNode.Extent.File) {
                $TypeNode.Extent.File
            } else {
                '<ScriptBlock>'
            }
            New-NitpickFinding `
                -RuleId $RuleId `
                -Message "The type '$($TypeNode.Extent.Text)' depends on an outer using namespace statement inside a dynamicparam block. Dynamic parameter evaluation may occur outside the original parse context; use a type name that remains resolvable there." `
                -ViolationExtent $TypeNode.Extent `
                -Severity $Metadata.Severity `
                -ScriptPath $FilePath `
                -Explanation $Metadata.Explanation
        }
    }

    foreach ($Call in $SerializedBlocks) {
        $MemberName = $Call.Member.Value
        $Candidate = if ($MemberName -eq 'ToString') {
            $Call.Expression
        } else {
            $Call.Arguments[0]
        }

        $Candidate = & $UnwrapExpression $Candidate
        if ($Candidate -is [InvokeMemberExpressionAst] -and
            $Candidate.Member -is [StringConstantExpressionAst] -and
            $Candidate.Member.Value -eq 'ToString'
        ) {
            $Candidate = $Candidate.Expression
        }

        $Block = & $ResolveScriptBlock $Candidate $Call
        if ($null -ne $Block) {
            foreach ($TypeNode in @(& $GetDependentTypeNodes $Block)) {
                $Offset = $TypeNode.Extent.StartOffset
                if ($ReportedTypeOffsets.ContainsKey($Offset)) { continue }
                $ReportedTypeOffsets[$Offset] = $true

                $FilePath = if ($TypeNode.Extent.File) {
                    $TypeNode.Extent.File
                } else {
                    '<ScriptBlock>'
                }
                New-NitpickFinding `
                    -RuleId $RuleId `
                    -Message "The type '$($TypeNode.Extent.Text)' depends on an outer using namespace statement, but this scriptblock is serialized for reparsing. Use a type name that remains resolvable in the isolated parse context, or suppress this finding when the destination supplies the required namespace." `
                    -ViolationExtent $TypeNode.Extent `
                    -Severity $Metadata.Severity `
                    -ScriptPath $FilePath `
                    -Explanation $Metadata.Explanation
            }
            continue
        }

        if ($MemberName -notin 'AddScript', 'Create' -or
            $Candidate -isnot [StringConstantExpressionAst]
        ) {
            continue
        }

        $NamespacePrefix = @(
            $NamespaceNames | ForEach-Object { "using namespace $_" }
        ) -join [Environment]::NewLine
        $Tokens = $null
        $ParseErrors = $null
        $StringAst = [Parser]::ParseInput(
            $NamespacePrefix + [Environment]::NewLine + $Candidate.Value,
            [ref] $Tokens,
            [ref] $ParseErrors
        )
        if ($ParseErrors.Count -gt 0) { continue }

        $DependentNodes = @(& $GetDependentTypeNodes $StringAst)
        if ($DependentNodes.Count -eq 0) { continue }

        $Offset = $Candidate.Extent.StartOffset
        if ($ReportedTypeOffsets.ContainsKey($Offset)) { continue }
        $ReportedTypeOffsets[$Offset] = $true

        $TypeNames = @(
            $DependentNodes |
                ForEach-Object { $_.Extent.Text } |
                Sort-Object -Unique
        )
        $FilePath = if ($Candidate.Extent.File) {
            $Candidate.Extent.File
        } else {
            '<ScriptBlock>'
        }
        New-NitpickFinding `
            -RuleId $RuleId `
            -Message "This script text uses type name(s) $($TypeNames -join ', ') that depend on the outer parse context. AddScript() and [scriptblock]::Create() reparse it without those outer using namespace statements." `
            -ViolationExtent $Candidate.Extent `
            -Severity $Metadata.Severity `
            -ScriptPath $FilePath `
            -Explanation $Metadata.Explanation
    }
}
