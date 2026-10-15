using namespace System.Management.Automation.Language
using namespace System.Collections.Generic

# Proof of concept for AstVisitorDispatch in the Nitpick module

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
    param(
        [FunctionDefinitionAst] $Ast
    )

    Write-Host "Visited function"
}

$ScriptblockAstScriptblock = {
    param(
        [ScriptBlockAst] $Ast
    )

    Write-Host "Visited scriptblock"
}

<#
.SYNOPSIS
    Analyzes callables for AST applicability and dispatches them accordingly
    in a single AST traversal.
#>
function Dispatcher {
    param(
        [Ast] $Ast,
        [ScriptBlock[]] $Callables
    )

    $VisitorMap = @{}

    foreach($Callable in $Callables) {

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
    Callables = @($FunctionAstScriptblock, $ScriptblockAstScriptblock)
}
Dispatcher @DispatcherParams
