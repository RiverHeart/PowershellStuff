<#
.SYNOPSIS
    Lexical analyzer for a simple TinyCompiler language.

.EXAMPLE
    Convert the following string into tokens:

    Lex 'mul 3 sub 2 sum 1 3 4'

    # Expected output: 'mul', '3', 'sub', '2', 'sum', '1', '3', '4'
#>
function Lex {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $String
    )

    process {
        $String.Trim().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries) |
            ForEach-Object { $_.Trim() } |
            Write-Output
    }
}

<#
.SYNOPSIS
    Parser for a simple TinyCompiler language.

.EXAMPLE
    Convert the following tokens into an abstract syntax tree (AST):

    Parse -Tokens @('mul', '3', 'sub', '2', 'sum', '1', '3', '4')

    # Expected output: a nested hashtable representing the AST
#>
function Parse {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $Tokens
    )

    begin {
        $i = 0

        function PeekToken { param($Tokens, [ref] $iRef) return $Tokens[$iRef.Value] }
        function NextToken { param($Tokens, [ref] $iRef) return $Tokens[$iRef.Value++] }

        function ParseNum {
            param($Tokens, [ref] $iRef)

            return @{ Value = [int]::Parse((NextToken $Tokens $iRef)); Type = 'Num' }
        }

        function ParseOp {
            param($Tokens, [ref] $iRef)

            $Node = @{ Value = NextToken $Tokens $iRef; Type = 'Op'; Expr = @() }
            while(PeekToken $Tokens $iRef) {
                $Node.Expr += ParseExpr $Tokens $iRef
            }
            return $Node
        }

        function ParseExpr {
            param($Tokens, [ref] $iRef)
            $CurrentToken = PeekToken $Tokens $iRef

            if ($CurrentToken -match '^\d+$') {
                return ParseNum $Tokens $iRef
            } else {
                return ParseOp $Tokens $iRef
            }
        }

        $FinalTokens = @()
    }

    process {
        $FinalTokens += $Tokens
    }

    end {
        return (ParseExpr $FinalTokens ([ref] $i))
    }
}

function Evaluate {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [hashtable] $Ast
    )
    begin {
        $OpAcMap = @{
            'sum' = { $args | Reduce-Object { param($acc, $curr) $acc + $curr } -InitialValue 0 }
            'sub' = { $args | Reduce-Object { param($acc, $curr) $acc - $curr } }
            'mul' = { $args | Reduce-Object { param($acc, $curr) $acc * $curr } }
            'div' = { $args | Reduce-Object { param($acc, $curr) $acc / $curr } -InitialValue 1 }
        }
    }

    process {
        if ($Ast.Type -eq 'Num') { return $Ast.Value }
        $Result = $Ast.Expr | ForEach-Object { Evaluate -Ast $_ }
        return & $OpAcMap[$Ast.Value] $Result
    }
}

function Compile {
    param(
        [Parameter(Mandatory)]
        [hashtable] $Ast
    )
    $opMap = @{
        sum = '+'
        mul = '*'
        sub = '-'
        div = '/'
    }
    function CompileNum { param([hashtable] $Ast) return $Ast.Value }
    function CompileOp {
        param([hashtable] $Ast)

        $CompiledExpr = $Ast.Expr | ForEach-Object { Compile -Ast $_ }
        return '(' + ($CompiledExpr -join " $($opMap[$Ast.Value]) ") + ')'
    }
    function CompileExpr {
        param([hashtable] $Ast)
        if ($Ast.Type -eq 'Num') { return CompileNum -Ast $Ast }
        return CompileOp -Ast $Ast
    }

    return CompileExpr -Ast $Ast
}

$Program = 'mul 3 sub 2 sum 1 3 4'

# Interpreter

$InterpreterResult = Evaluate (Parse (Lex $Program))
Write-Output "Interpreter Result: $InterpreterResult"

# Expected result: 3 * (2 - (1 + 3 + 4)) = 3 * (2 - 8) = 3 * -6 = -18

$CompiledResult = Compile (Parse (Lex $Program))
Write-Output "Compiled Result: $CompiledResult"

# Expected result: (3 * (2 - (1 + 3 + 4)))
