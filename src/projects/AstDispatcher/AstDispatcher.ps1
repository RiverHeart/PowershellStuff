using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

# Proof of concept for AstVisitorDispatch in the Nitpick module

class CallableMetadataAttribute : System.Attribute {
    #$Target = [AttributeTargets]::All
    #[System.AttributeUsage($Target)]

    [hashtable] $Metadata

    CallableMetadataAttribute([scriptblock] $Metadata) {
        $this.Metadata = $Metadata.Invoke()
    }
}


# Test scriptblock
$TestScriptblock = {
    param($word)

    function Test-Function {
        param($input)
        $input
    }

    Write-Host "Processing word: $word"
    $result = Test-Function $word

    {
        Write-Host "Inside empty block"
    }.Invoke()

    return $result
}

$FunctionAstScriptblock = {
    [CallableMetadataAttribute({@{
        Type = "FunctionDefinitionAst"
    }})]
    param(
        [FunctionDefinitionAst] $Ast
    )

    Write-Host "Visited function"
}

$ScriptblockAstScriptblock = {
    [CallableMetadataAttribute({@{
        Type = "ScriptBlockAst"
    }})]
    param(
        [ScriptBlockAst] $Ast
    )

    Write-Host "Visited scriptblock"
}

function VariableExpressionAst {
    [CallableMetadataAttribute({@{
        Type = "VariableExpressionAst"
    }})]
    param(
        [VariableExpressionAst] $Ast
    )

    Write-Host "Visited variable expression"
}

<#
.SYNOPSIS
    Analyzes callables for AST applicability and dispatches them accordingly
    in a single AST traversal.
#>
function Dispatcher {
    param(
        [Ast] $Ast,

        [ValidateScript({ $_ -is [ScriptBlock] -or $_ -is [CommandInfo] })]
        [object[]] $Callables
    )

    $VisitorMap = @{}

    foreach($Callable in $Callables) {

        # While cute, not being able to rely on CallableMetadataAttribute at parse
        # time means using this attribute won't be viable...
        $Metadata = @{}
        if ($Callable -is [Scriptblock]) {
            $MetadataAttributeAst = $Callable.Ast.ParamBlock.Attributes |
                Where-Object { $_.TypeName.Name -eq 'CallableMetadataAttribute' } |
                Select-Object -First 1

            $Metadata = $MetadataAttributeAst.Find({
                    param($AstNode)
                    $AstNode -is [HashtableAst]
                }, $true) |
                ForEach-Object {
                    $_.SafeGetValue()
                }
        } elseif ($Callable -is [CommandInfo]) {
            $RawMetadata = $Callable.Attributes | Where-Object { $_ -is [CallableMetadataAttribute] } | Select-Object -First 1
        } else {
            throw "Unsupported callable type: $($Callable.GetType().FullName)"
        }

        # NOTE: Not sure if callables should be allowed to support multiple types
        $InterestingTypes = $Callable.Ast.ParamBlock.Parameters.Attributes.TypeName.Name |
            Where-Object { $_ -like '*Ast' } |
            Select-Object -First 1

        # For each interesting type, add the callable to the visitor map
        foreach($Type in $InterestingTypes) {
            if (-not $VisitorMap.ContainsKey($Type)) {
                Write-Host "Initializing visitor for type: $Type"
                # Initialize the visitor and the list of callables for this type
                $VisitorMap[$Type] = [List[ScriptBlock]]::new()
            }
            $VisitorMap[$Type].Add($Callable)
        }
    }

    # Visit every node in the AST and run each callable
    # against its interested type
    $Ast.FindAll({
        param($AstNode)
        $TypeName = $AstNode.GetType().Name
        return $VisitorMap.ContainsKey($TypeName)

    }, $true) | ForEach-Object {
        $Node = $_
        $TypeName = $Node.GetType().Name
        foreach ($Callable in $VisitorMap[$TypeName]) {
            & $Callable $Node
        }
    }
}

$DispatcherParams = @{
    Ast = $TestScriptblock.Ast
    Callables = @(
        $FunctionAstScriptblock,
        $ScriptblockAstScriptblock,
        (Get-Command VariableExpressionAst)
    )
}
Dispatcher @DispatcherParams
