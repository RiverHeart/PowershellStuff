using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
    Import-Module (Join-Path $PSScriptRoot '../../../../AstEditor/AstEditor.psd1') -Force
    Import-Module (Join-Path $PSScriptRoot '../../../Nitpick.psd1') -Force

    # This predicate specifies the bounded syntax, not a production fix provider.
    function Get-IsNotContractMatch {
        param (
            [ScriptBlockAst] $Ast
        )

        # Redirection/background execution changes the value seen by outer -not;
        # moving negation into the type test is not equivalent for those pipelines.
        $Ast.FindAll({
            param ($Node)

            $Node -is [UnaryExpressionAst] -and
                $Node.TokenKind -eq [TokenKind]::Not -and
                $Node.Child -is [ParenExpressionAst] -and
                $Node.Child.Pipeline -is [PipelineAst] -and
                $Node.Child.Pipeline.PipelineElements.Count -eq 1 -and
                $Node.Child.Pipeline.PipelineElements[0] -is [CommandExpressionAst] -and
                $Node.Child.Pipeline.PipelineElements[0].Redirections.Count -eq 0 -and
                -not (
                    $Node.Child.Pipeline.PSObject.Properties['Background'] -and
                    $Node.Child.Pipeline.Background
                ) -and
                $Node.Child.Pipeline.PipelineElements[0].Expression -is [BinaryExpressionAst] -and
                $Node.Child.Pipeline.PipelineElements[0].Expression.Operator -eq [TokenKind]::Is
        }, $false)
    }
}

Describe 'UseIsNotOperator structural syntax contracts' -Tag 'AutocorrectionContract' {
    BeforeDiscovery {
        $Cases = @(
            @{ Label = 'ordinary spacing'; Source = '-not ($Value -is [int])'; Expected = ' ($Value -isnot [int])'; Count = 1 }
            @{ Label = 'adjacent parentheses and operator casing'; Source = '-NOT($Value -IS [int])'; Expected = '($Value -isnot [int])'; Count = 1 }
            @{ Label = 'string operand'; Source = '-not (''literal -is'' -is [string])'; Expected = ' (''literal -is'' -isnot [string])'; Count = 1 }
            @{ Label = 'variable operand'; Source = '-not (${name-is} -is [string])'; Expected = ' (${name-is} -isnot [string])'; Count = 1 }
            @{ Label = 'comment trivia'; Source = '-not <# keep -not #> (<# -is #> $Value <# -is #> -is [int])'; Expected = ' <# keep -not #> (<# -is #> $Value <# -is #> -isnot [int])'; Count = 1 }
            @{ Label = 'LF trivia'; Source = "-not (`n`$Value -is [int]`n)"; Expected = " (`n`$Value -isnot [int]`n)"; Count = 1 }
            @{ Label = 'CRLF trivia'; Source = "-not (`r`n`$Value -is [int]`r`n)"; Expected = " (`r`n`$Value -isnot [int]`r`n)"; Count = 1 }
            @{ Label = 'two independent occurrences'; Source = '-not ($Value -is [int]); -not ($Other -is [string])'; Expected = ' ($Value -isnot [int]);  ($Other -isnot [string])'; Count = 2 }
            @{ Label = 'nested matching expressions'; Source = '-not (-not ($Value -is [int]) -is [bool])'; Expected = ' ( ($Value -isnot [int]) -isnot [bool])'; Count = 2 }
        )
        $DiagnosticOnlyCases = @(
            @{ Source = '-not ($Value -is [int] > $Path)' }
        )
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $DiagnosticOnlyCases += @{ Source = '-not ($Value -is [int] &)' }
        }
    }

    It 'can render two precise detached token edits per match: <Label>' -ForEach $Cases {
        $Document = New-AstDocument -InputObject $Source
        $Document.ParseErrors | Should -BeNullOrEmpty
        $Matches = @(Get-IsNotContractMatch -Ast $Document.Ast)
        $Matches | Should -HaveCount $Count
        $Edits = @(
            foreach ($Match in $Matches) {
                $Binary = $Match.Child.Pipeline.PipelineElements[0].Expression
                $Negation = @($Document.Tokens | Where-Object {
                    $_.Kind -eq [TokenKind]::Not -and
                        $_.Extent.StartOffset -eq $Match.Extent.StartOffset -and
                        $_.Extent.EndOffset -le $Match.Child.Extent.StartOffset
                })
                $Operator = @($Document.Tokens | Where-Object {
                    $_.Kind -eq [TokenKind]::Is -and
                        $_.Extent.StartOffset -ge $Binary.Left.Extent.EndOffset -and
                        $_.Extent.EndOffset -le $Binary.Right.Extent.StartOffset
                })
                $Negation | Should -HaveCount 1
                $Operator | Should -HaveCount 1
                New-AstTextEdit -Extent $Negation[0].Extent -ReplacementText '' -Reason 'Remove unary negation'
                New-AstTextEdit -Extent $Operator[0].Extent -ReplacementText '-isnot' -Reason 'Negate the type test'
            }
        )

        $Edits | Should -HaveCount ($Count * 2)
        $Document.Edits.Count | Should -Be 0
        foreach ($Edit in $Edits) {
            $Edit.ExpectedText | Should -BeExactly $Source.Substring(
                $Edit.StartOffset,
                $Edit.EndOffset - $Edit.StartOffset
            )
        }
        $null = Add-AstTextEdit -Document $Document -TextEdit $Edits
        $Resolution = Resolve-AstDocument -Document $Document -PassThruText

        $Resolution.ParseErrors | Should -BeNullOrEmpty
        $Resolution.RenderedText | Should -BeExactly $Expected
        $RenderedDocument = New-AstDocument -InputObject $Resolution.RenderedText
        @(Get-IsNotContractMatch -Ast $RenderedDocument.Ast) | Should -HaveCount 0
    }

    It 'excludes syntax outside the first transformation: <Source>' -ForEach @(
        @{ Source = '!($Value -is [int])' }
        @{ Source = '-not (($Value -is [int]))' }
        @{ Source = '-not ($Value -is [int] | Write-Output)' }
        @{ Source = '-not ($Value -eq 1)' }
        @{ Source = '$Value -isnot [int]' }
        @{ Source = '& { -not ($Value -is [int]) }' }
    ) {
        $Document = New-AstDocument -InputObject $Source
        $Document.ParseErrors | Should -BeNullOrEmpty
        @(Get-IsNotContractMatch -Ast $Document.Ast) | Should -HaveCount 0
    }

    It 'excludes pipeline chains across parser editions' {
        $Document = New-AstDocument -InputObject '-not ($Value -is [int] && $true)'

        if ($PSVersionTable.PSVersion.Major -lt 7) {
            @($Document.ParseErrors).Count | Should -BeGreaterThan 0
        } else {
            $Document.ParseErrors | Should -BeNullOrEmpty
        }
        @(Get-IsNotContractMatch -Ast $Document.Ast) | Should -HaveCount 0
    }

    It 'does not plan a Safe fix for value-changing pipeline execution: <Source>' -ForEach $DiagnosticOnlyCases {
        $Document = New-AstDocument -InputObject $Source

        $Document.ParseErrors | Should -BeNullOrEmpty
        @(Get-IsNotContractMatch -Ast $Document.Ast) | Should -HaveCount 0
    }

    It 'preserves the Boolean type-test result for <Label>' -ForEach @(
        @{ Label = 'integer'; Value = 1 }
        @{ Label = 'string'; Value = 'literal -is' }
        @{ Label = 'null'; Value = $null }
        @{ Label = 'array'; Value = @(1, 2) }
    ) {
        $Original = -not ($Value -is [int])
        $Corrected = ($Value -isnot [int])

        $Corrected | Should -BeExactly $Original
        $Corrected | Should -BeOfType ([bool])
    }

    It 'emits native coordinated corrections and previews exact text: <Label>' -ForEach $Cases {
        $Document = New-AstDocument -InputObject $Source
        $Rule = New-Nitpick -Callable Test-UseIsNotOperator
        $Findings = @($Rule.Invoke($Document.Ast))

        $Findings | Should -HaveCount $Count
        $Document.Edits.Count | Should -Be 0
        foreach ($Finding in $Findings) {
            $Finding.GetType().Name | Should -Be 'NitpickFinding'
            $Finding.Corrections | Should -HaveCount 2
            @($Finding.Corrections.ChangeSetId | Select-Object -Unique) | Should -HaveCount 1
            $Finding.Corrections[0].ChangeSetId | Should -BeExactly (
                'UseIsNotOperator:{0}:{1}' -f
                    $Finding.ViolationExtent.StartOffset,
                    $Finding.ViolationExtent.EndOffset
            )
            foreach ($Correction in $Finding.Corrections) {
                $Correction.Applicability | Should -Be 'Safe'
                $Correction.RuleName | Should -Be 'UseIsNotOperator'
                $Correction.TextEdit.GetType().Name | Should -Be 'AstTextEdit'
                $Correction.Description | Should -Not -BeNullOrEmpty
                $Correction.ExpectedText | Should -BeExactly $Source.Substring(
                    $Correction.StartOffset,
                    $Correction.EndOffset - $Correction.StartOffset
                )
            }
            $Finding.Corrections[0].StartOffset | Should -Be $Finding.ViolationExtent.StartOffset
            $Finding.Corrections[0].ExpectedText | Should -Be '-not'
            $Finding.Corrections[0].ReplacementText | Should -BeExactly ''
            $Finding.Corrections[1].ExpectedText | Should -Be '-is'
            $Finding.Corrections[1].ReplacementText | Should -BeExactly '-isnot'
        }
        @($Findings.Corrections.ChangeSetId | Select-Object -Unique) | Should -HaveCount $Count
        $Result = Resolve-NitpickCorrection -Document $Document -Finding $Findings -Rule $Rule

        $Result.RenderedText | Should -BeExactly $Expected
        $Result.Corrections.Accepted | Should -HaveCount ($Count * 2)
        $Result.Corrections.Skipped | Should -HaveCount 0
        $Result.Findings.Final | Should -HaveCount 0
    }

    It 'retains a native diagnostic without corrections for <Source>' -ForEach $DiagnosticOnlyCases {
        $Document = New-AstDocument -InputObject $Source
        $Rule = New-Nitpick -Callable Test-UseIsNotOperator
        $Findings = @($Rule.Invoke($Document.Ast))

        $Findings | Should -HaveCount 1
        $Findings[0].GetType().Name | Should -Be 'NitpickFinding'
        $Findings[0].RuleName | Should -Be 'UseIsNotOperator'
        $Findings[0].Corrections | Should -BeNullOrEmpty
    }

    It 'retains file provenance and absolute offsets when analyzing a nested script block' {
        $Path = Join-Path $TestDrive 'Nested.ps1'
        $Source = "# prefix`nfunction Test-Value { -not ('literal -is' -is [string]) }"
        [System.IO.File]::WriteAllText($Path, $Source)
        $Document = New-AstDocument -Path $Path
        $Function = $Document.Ast.Find({
            param ($Node)

            $Node -is [FunctionDefinitionAst]
        }, $false)
        $Rule = New-Nitpick -Callable Test-UseIsNotOperator
        $Findings = @($Rule.Invoke($Function.Body))

        $Findings | Should -HaveCount 1
        $Findings[0].ViolationExtent.File | Should -BeExactly $Document.Path
        $Findings[0].Location | Should -BeLike "$($Document.Path):2:*"
        foreach ($Correction in $Findings[0].Corrections) {
            $Correction.FilePathOrContext | Should -BeExactly $Document.Path
            $Correction.StartLineNumber | Should -Be 2
            $Correction.ExpectedText | Should -BeExactly $Source.Substring(
                $Correction.StartOffset,
                $Correction.EndOffset - $Correction.StartOffset
            )
        }
        $Result = Resolve-NitpickCorrection -Document $Document -Finding $Findings

        $Result.RenderedText | Should -BeExactly (
            "# prefix`nfunction Test-Value {  ('literal -is' -isnot [string]) }"
        )
        [System.IO.File]::ReadAllText($Path) | Should -BeExactly $Source
    }

    It 'does not expand production detection to <Source>' -ForEach @(
        @{ Source = '!($Value -is [int])' }
        @{ Source = '-not (($Value -is [int]))' }
        @{ Source = '-not ($Value -is [int] | Write-Output)' }
        @{ Source = '& { -not ($Value -is [int]) }' }
    ) {
        $Document = New-AstDocument -InputObject $Source
        $Rule = New-Nitpick -Callable Test-UseIsNotOperator

        @($Rule.Invoke($Document.Ast)) | Should -HaveCount 0
    }

    It 'returns a direct ScriptAnalyzer diagnostic without suggestions' {
        $Findings = @(Test-UseIsNotOperator -ScriptBlockAst { -not ($Value -is [int]) }.Ast)

        $Findings | Should -HaveCount 1
        $Findings[0].GetType().FullName |
            Should -Be 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord'
        $Findings[0].SuggestedCorrections | Should -BeNullOrEmpty
    }

    It 'corrects subexpressions in interpolated strings without changing literal text: <Label>' -ForEach @(
        @{
            Label = 'one interpolation'
            Source = '"literal -is $(-not ($Value -is [int]))"'
            Expected = '"literal -is $( ($Value -isnot [int]))"'
        }
        @{
            Label = 'nested interpolated strings'
            Source = '"outer $("-is $(-not ($Value -is [int]))")"'
            Expected = '"outer $("-is $( ($Value -isnot [int]))")"'
        }
    ) {
        $Document = New-AstDocument -InputObject $Source
        $Rule = New-Nitpick -Callable Test-UseIsNotOperator
        $Findings = @($Rule.Invoke($Document.Ast))

        $Document.ParseErrors | Should -BeNullOrEmpty
        $Findings | Should -HaveCount 1
        $Findings[0].Corrections | Should -HaveCount 2
        $Result = Resolve-NitpickCorrection -Document $Document -Finding $Findings -Rule $Rule

        $Result.RenderedText | Should -BeExactly $Expected
        $Result.Corrections.Accepted | Should -HaveCount 2
        $Result.Findings.Final | Should -HaveCount 0
    }

    It 'retains diagnostics but exposes no partial ScriptAnalyzer fix' {
        $Results = @(Invoke-ScriptAnalyzer `
            -ScriptDefinition '-not (''literal -is'' -is [string])' `
            -CustomRulePath (Join-Path $PSScriptRoot '../../../Nitpick.psd1') `
            -IncludeRule Test-UseIsNotOperator `
            -Settings @{})

        $Results | Should -HaveCount 1
        $Results[0].RuleName | Should -Be 'UseIsNotOperator'
        @($Results[0].SuggestedCorrections) | Should -HaveCount 0
        $Rule = New-Nitpick -Callable Test-UseIsNotOperator
        $Finding = @($Rule.Invoke({ -not ($Value -is [int]) }.Ast))[0]
        @($Finding.ToDiagnosticRecord().SuggestedCorrections) | Should -HaveCount 0
    }
}
