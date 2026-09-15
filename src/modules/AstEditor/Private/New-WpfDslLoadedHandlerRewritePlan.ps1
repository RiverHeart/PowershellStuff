<#
.SYNOPSIS
    Builds a minimal rewrite plan for the WPF Loaded-handler transform.

.DESCRIPTION
    Produces a small semantic descriptor that tells the emitter what to do.
    The plan keeps target selection and rewrite intent separate from text emission.
#>
function New-WpfDslLoadedHandlerRewritePlan {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [AstDocument] $Document,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $HandlerBody = "Write-Verbose 'Loaded handler inserted by AST overlay prototype.'",

        [Parameter()]
        [ValidateSet('Skip', 'InsertAfterExisting', 'AppendToExistingBody')]
        [string] $OnExistingHandler = 'Skip',

        [switch] $AllowDuplicateHandlerBody,

        [switch] $Force
    )

    $WindowCommand = Find-AstNode -Ast $Document.Ast -Recurse -Query {
        param($Node)

        if (-not ($Node -is [CommandAst])) {
            return $false
        }

        if ($Node.GetCommandName() -ne 'Window') {
            return $false
        }

        return ($Node.CommandElements | Where-Object { $_ -is [ScriptBlockExpressionAst] }).Count -gt 0
    }

    if (-not $WindowCommand) {
        throw 'No WPF DSL Window command was found.'
    }

    $WindowScriptBlockExpression = $WindowCommand.CommandElements | Where-Object {
        $_ -is [ScriptBlockExpressionAst]
    } | Select-Object -First 1

    if (-not $WindowScriptBlockExpression) {
        throw 'Window command found but no scriptblock argument was detected.'
    }

    $WindowScriptBlockAst = $WindowScriptBlockExpression.ScriptBlock
    $LoadedWhenCommands = Find-AstNode -Ast $WindowScriptBlockAst -Recurse -All -Query {
        param($Node)

        if (-not ($Node -is [CommandAst])) {
            return $false
        }

        if ($Node.GetCommandName() -ne 'When') {
            return $false
        }

        if ($Node.CommandElements.Count -lt 2) {
            return $false
        }

        $Literal = $Node.CommandElements[1]
        if (-not ($Literal -is [StringConstantExpressionAst])) {
            return $false
        }

        return $Literal.Value -eq 'Loaded'
    }

    $HandlerBodyScriptBlock = [ScriptBlock]::Create($HandlerBody)

    $ExistingLoadedHandler = $null
    $HandlerBodyAlreadyPresent = $false
    foreach ($LoadedWhenCommand in $LoadedWhenCommands) {
        $LoadedHandlerScriptBlockExpression = $LoadedWhenCommand.CommandElements | Where-Object {
            $_ -is [ScriptBlockExpressionAst]
        } | Select-Object -First 1

        if (-not $LoadedHandlerScriptBlockExpression) {
            continue
        }

        if (Test-ScriptBlockStatementTextEquivalent -Left $LoadedHandlerScriptBlockExpression.ScriptBlock -Right $HandlerBodyScriptBlock.Ast) {
            $ExistingLoadedHandler = $LoadedWhenCommand
            $HandlerBodyAlreadyPresent = $true
            break
        }
    }

    $ContainsLoadedWhen = $LoadedWhenCommands.Count -gt 0
    if ($ContainsLoadedWhen -and $Force -and $OnExistingHandler -eq 'Skip') {
        $OnExistingHandler = 'InsertAfterExisting'
    }

    $Action = 'None'
    $TargetAst = $null
    $Text = $null
    $Reason = $null

    if ($ContainsLoadedWhen -and -not $AllowDuplicateHandlerBody -and $HandlerBodyAlreadyPresent) {
        $Reason = 'Handler body already present.'
    } elseif ($ContainsLoadedWhen -and $OnExistingHandler -eq 'Skip') {
        $Reason = 'Existing handler policy is Skip.'
    } elseif ($ContainsLoadedWhen -and $OnExistingHandler -eq 'InsertAfterExisting') {
        $Action = 'InsertAfterExisting'
        $TargetAst = $LoadedWhenCommands | Select-Object -First 1
        $Text = "`r`n    When 'Loaded' {`r`n        $HandlerBody`r`n    }`r`n"
        $Reason = 'Insert sibling When Loaded handler after existing handler.'
    } elseif ($ContainsLoadedWhen -and $OnExistingHandler -eq 'AppendToExistingBody') {
        $Action = 'AppendToExistingBody'
        $TargetAst = $LoadedWhenCommands | Select-Object -First 1
        $ExistingHandlerScriptBlockExpression = $TargetAst.CommandElements | Where-Object {
            $_ -is [ScriptBlockExpressionAst]
        } | Select-Object -First 1

        if (-not $ExistingHandlerScriptBlockExpression) {
            throw "Loaded handler was detected but no scriptblock body was found."
        }

        $WhenIndent = ' ' * ($TargetAst.Extent.StartColumnNumber - 1)
        $BodyIndent = "$WhenIndent    "
        $Text = "`r`n$BodyIndent$HandlerBody`r`n$WhenIndent"
        $Reason = 'Append text to existing When Loaded handler body.'
    } else {
        $Action = 'InsertMissingHandler'
        $TargetAst = $WindowScriptBlockAst
        $Text = "`r`n    When 'Loaded' {`r`n        $HandlerBody`r`n    }`r`n"
        $Reason = 'Add missing When Loaded handler.'
    }

    return [pscustomobject] @{
        Action = $Action
        TargetAst = $TargetAst
        Text = $Text
        Reason = $Reason
        HasLoadedWhen = $ContainsLoadedWhen
        HandlerBodyAlreadyPresent = $HandlerBodyAlreadyPresent
    }
}
