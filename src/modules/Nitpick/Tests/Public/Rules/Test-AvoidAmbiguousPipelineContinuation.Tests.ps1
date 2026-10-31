using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    Import-Module (Join-Path $PSScriptRoot '../../../Nitpick.psd1') -Force -ErrorAction Stop

    function Invoke-ContinuationRule {
        param(
            [string] $Source,
            [bool] $Recurse = $false
        )

        $Tokens = $null
        $ParseErrors = $null
        $Ast = [Parser]::ParseInput($Source, [ref] $Tokens, [ref] $ParseErrors)
        $ParseErrors | Should -BeNullOrEmpty
        Test-AvoidAmbiguousPipelineContinuation -ScriptBlockAst $Ast -Context @{
            RuleBehavior = @{
                OutputType = 'NitpickFinding'
                SearchNestedScriptBlocks = $Recurse
            }
        }
    }
}

Describe 'Test-AvoidAmbiguousPipelineContinuation' {
    It 'reports <Label>' -ForEach @(
        @{ Label = 'a bare pipeline'; Source = "Get-ChildItem |`n    Where-Object { `$_.Name }`n    ForEach-Object { `$_.FullName }" }
        @{ Label = 'an assigned pipeline'; Source = "`$Files = Get-ChildItem |`n    Where-Object { `$_.Name }`n    ForEach-Object { `$_.FullName }" }
        @{ Label = 'a multiline final scriptblock'; Source = "Get-ChildItem |`n    Where-Object {`n        `$_.Name`n    }`n    ForEach-Object { `$_.FullName }" }
        @{ Label = 'CRLF'; Source = "Get-ChildItem |`r`n    Where-Object { `$_.Name }`r`n    ForEach-Object { `$_.FullName }" }
        @{ Label = 'tab indentation'; Source = "Get-ChildItem |`n`tWhere-Object { `$_.Name }`n`tForEach-Object { `$_.FullName }" }
        @{ Label = 'an alias'; Source = "Get-ChildItem |`n    Where-Object { `$_.Name }`n    % { `$_.FullName }" }
        @{ Label = 'an arbitrary function'; Source = "Get-ChildItem |`n    Where-Object { `$_.Name }`n    Invoke-CustomOperation" }
        @{ Label = 'a native command'; Source = "Get-ChildItem |`n    Where-Object { `$_.Name }`n    sort.exe" }
        @{ Label = 'a following pipeline'; Source = "Get-ChildItem |`n    Where-Object { `$_.Name }`n    Write-Output value | Out-String" }
        @{ Label = 'a control-flow body'; Source = "if (`$true) {`n    Get-ChildItem |`n        Where-Object { `$_.Name }`n        ForEach-Object { `$_.FullName }`n}" }
        @{ Label = 'a subexpression'; Source = "`$(Get-ChildItem |`n    Where-Object { `$_.Name }`n    ForEach-Object { `$_.FullName })" }
    ) {
        $Result = @(Invoke-ContinuationRule -Source $Source)
        $Result | Should -HaveCount 1
        $Result[0].RuleName | Should -Be 'AvoidAmbiguousPipelineContinuation'
        $Result[0].Severity | Should -Be 'Warning'
        $Result[0].Message | Should -BeLike 'Ambiguous pipeline continuation:*'
        $Result[0].Message | Should -BeLike "*Add '|'*blank line*dedent*"
        $Result[0].Corrections | Should -BeNullOrEmpty
    }

    It 'does not report <Label>' -ForEach @(
        @{ Label = 'an actual continuation'; Source = "Get-ChildItem |`n    Where-Object { `$_.Name } |`n    ForEach-Object { `$_.FullName }" }
        @{ Label = 'a blank line'; Source = "Get-ChildItem |`n    Where-Object { `$_.Name }`n`n    ForEach-Object { `$_.FullName }" }
        @{ Label = 'a whitespace-only blank line'; Source = "Get-ChildItem |`n    Where-Object { `$_.Name }`n    `n    ForEach-Object { `$_.FullName }" }
        @{ Label = 'a dedented command'; Source = "Get-ChildItem |`n    Where-Object { `$_.Name }`nForEach-Object { `$_.FullName }" }
        @{ Label = 'a differently indented command'; Source = "Get-ChildItem |`n    Where-Object { `$_.Name }`n  ForEach-Object { `$_.FullName }" }
        @{ Label = 'an unindented pipeline'; Source = "Get-ChildItem |`nWhere-Object { `$_.Name }`nForEach-Object { `$_.FullName }" }
        @{ Label = 'a single-line pipeline'; Source = "Get-ChildItem | Where-Object { `$_.Name }`n    ForEach-Object { `$_.FullName }" }
        @{ Label = 'a single command'; Source = "Get-ChildItem`n    ForEach-Object { `$_.FullName }" }
        @{ Label = 'a following assignment'; Source = "Get-ChildItem |`n    Where-Object { `$_.Name }`n    `$Value = Get-Item ." }
        @{ Label = 'a following expression'; Source = "Get-ChildItem |`n    Where-Object { `$_.Name }`n    `$Value" }
        @{ Label = 'a following control statement'; Source = "Get-ChildItem |`n    Where-Object { `$_.Name }`n    if (`$true) {}" }
        @{ Label = 'a semicolon'; Source = "Get-ChildItem |`n    Where-Object { `$_.Name };`n    ForEach-Object { `$_.FullName }" }
        @{ Label = 'a trailing comment'; Source = "Get-ChildItem |`n    Where-Object { `$_.Name } # complete`n    ForEach-Object { `$_.FullName }" }
        @{ Label = 'an intervening comment'; Source = "Get-ChildItem |`n    Where-Object { `$_.Name }`n    # separate`n    ForEach-Object { `$_.FullName }" }
        @{ Label = 'a leading block comment'; Source = "Get-ChildItem |`n    Where-Object { `$_.Name }`n    <# separate #> ForEach-Object { `$_.FullName }" }
        @{ Label = 'different statement lists'; Source = "if (`$true) { Get-ChildItem |`n    Where-Object { `$_.Name }`n}`n    ForEach-Object { `$_.FullName }" }
        @{ Label = 'an expression-led pipeline'; Source = "`$Files |`n    Where-Object { `$_.Name }`n    ForEach-Object { `$_.FullName }" }
    ) {
        @(Invoke-ContinuationRule -Source $Source) | Should -HaveCount 0
    }

    It 'respects nested scriptblock traversal' {
        $Source = "function Invoke-Example {`n    Get-ChildItem |`n        Where-Object { `$_.Name }`n        ForEach-Object { `$_.FullName }`n}"
        @(Invoke-ContinuationRule -Source $Source) | Should -HaveCount 0
        @(Invoke-ContinuationRule -Source $Source -Recurse $true) | Should -HaveCount 1
    }

    It 'uses full-source offsets when invoked on a nested scriptblock AST' {
        $Ast = {
            function Invoke-Example {
                Get-ChildItem |
                    Where-Object { $_.Name }
                    ForEach-Object { $_.FullName }
            }
        }.Ast
        $Body = $Ast.Find({ param($Node) $Node -is [FunctionDefinitionAst] }, $false).Body
        $Result = @(Test-AvoidAmbiguousPipelineContinuation -ScriptBlockAst $Body -Context @{
            RuleBehavior = @{ OutputType = 'NitpickFinding' }
        })
        $Result | Should -HaveCount 1
    }

    It 'defaults to ScriptAnalyzer diagnostics pointing at the separate command' {
        $Ast = {
            Get-ChildItem |
                Where-Object { $_.Name }
                ForEach-Object { $_.FullName }
        }.Ast
        $Result = @(Test-AvoidAmbiguousPipelineContinuation -ScriptBlockAst $Ast)
        $Result | Should -HaveCount 1
        $Result[0].GetType().Name | Should -Be 'DiagnosticRecord'
        $Result[0].Extent.Text | Should -Be 'ForEach-Object'
        $Result[0].RuleSuppressionID | Should -Be 'AvoidAmbiguousPipelineContinuation'
        $Result[0].SuggestedCorrections | Should -BeNullOrEmpty
    }

    It 'is discoverable and assigns coordinated identity' {
        $Rule = @(Find-Nitpick -IncludeRule 'Nitpick/AvoidAmbiguousPipelineContinuation')
        $Rule | Should -HaveCount 1
        $Ast = {
            Get-ChildItem |
                Where-Object { $_.Name }
                ForEach-Object { $_.FullName }
        }.Ast
        $Result = @($Rule[0].Invoke($Ast))
        $Result | Should -HaveCount 1
        $Result[0].RuleId | Should -Be 'Nitpick/AvoidAmbiguousPipelineContinuation'
    }

    It 'provides metadata without requiring an AST' {
        $Details = Test-AvoidAmbiguousPipelineContinuation -Details
        $Details.Name | Should -Be 'AvoidAmbiguousPipelineContinuation'
        $Details.Category | Should -Be 'Style'
        $Details.Severity | Should -Be 'Warning'
    }

    It 'reports nested ScriptAnalyzer violations exactly once without suggesting a fix' {
        $Source = @'
function Invoke-Example {
    Get-ChildItem |
        Where-Object { $_.Name }
        ForEach-Object { $_.FullName }
    & {
        Get-ChildItem |
            Where-Object { $_.Name }
            ForEach-Object { $_.FullName }
    }
}
'@
        $Results = @(Invoke-ScriptAnalyzer -ScriptDefinition $Source `
            -CustomRulePath (Join-Path $PSScriptRoot '../../../Nitpick.psd1') `
            -IncludeRule Test-AvoidAmbiguousPipelineContinuation -Settings @{})
        $Results | Should -HaveCount 2
        @($Results | ForEach-Object { $_.Extent.StartOffset } | Sort-Object -Unique) |
            Should -HaveCount 2
        foreach ($Result in $Results) {
            $Result.RuleName | Should -Be 'AvoidAmbiguousPipelineContinuation'
            $Result.SuggestedCorrections | Should -BeNullOrEmpty
        }
    }
}
