using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module PSScriptAnalyzer -ErrorAction Stop
    Import-Module "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force
    $PreviousQuietWhatIf = $env:WHATIF__QUIET
    $env:WHATIF__QUIET = $true
}

AfterAll {
    Remove-Module Nitpick -Force -ErrorAction SilentlyContinue
    $env:WHATIF__QUIET = $PreviousQuietWhatIf
}

Describe 'AvoidTrailingWhitespace' {
    It 'trims ordinary trivia and preserves <Name> line endings' -ForEach @(
        @{ Name = 'CRLF'; NewLine = "`r`n" }
        @{ Name = 'LF'; NewLine = "`n" }
        @{ Name = 'CR'; NewLine = "`r" }
    ) {
        #=== Arrange ===#
        $Source = '$Value = 1  ' + $NewLine + " `t" + $NewLine + '# comment  ' + $NewLine + '$Other = 2' + "`t "
        $Expected = '$Value = 1' + $NewLine + $NewLine + '# comment' + $NewLine + '$Other = 2'
        $Document = New-AstDocument -InputObject $Source
        $Rule = New-Nitpick -Callable Measure-AvoidTrailingWhitespace

        #=== Act ===#
        $Findings = @($Rule.Invoke($Document))

        #=== Assert ===#
        $Findings | Should -HaveCount 4
        foreach ($Finding in $Findings) {
            $Finding.RuleId | Should -Be 'Nitpick/AvoidTrailingWhitespace'
            $Finding.ViolationExtent.Text | Should -Match '^[ \t]+$'
            $Finding.Corrections | Should -HaveCount 1
            $Finding.Corrections[0].Applicability | Should -Be 'Safe'
        }

        $Proposal = Resolve-NitpickCorrectionProposal `
            -Document $Document `
            -Finding $Findings `
            -Rule $Rule

        $Proposal.CandidateText | Should -BeExactly $Expected
        $Proposal.CandidateFindings | Should -HaveCount 0
        $Proposal.WasReanalyzed | Should -BeTrue
    }

    It 'preserves meaningful whitespace in <Label>' -ForEach @(
        @{ Label = 'literal multiline string'; Source = "'first  `nsecond'"; Count = 0 }
        @{ Label = 'expandable multiline string'; Source = '"first  ' + "`n" + 'second"'; Count = 0 }
        @{ Label = 'literal here-string'; Source = "@'`nfirst  `n'@"; Count = 0 }
        @{ Label = 'expandable here-string'; Source = '@"' + "`nfirst  `n" + '"@'; Count = 0 }
        @{ Label = 'backtick escaped space'; Source = 'Write-Output value` ' + "`n"; Count = 0 }
        @{ Label = 'backtick escaped tab'; Source = 'Write-Output value`' + "`t`n"; Count = 0 }
        @{ Label = 'escaped suffix run'; Source = 'Write-Output value`   ' + "`n"; Count = 0 }
        @{ Label = 'closing quote followed by whitespace'; Source = '"value"  '; Count = 1 }
        @{ Label = 'escaped backtick followed by whitespace'; Source = 'Write-Output value``  '; Count = 1 }
        @{ Label = 'backtick in a line comment'; Source = '# comment`  '; Count = 1 }
        @{ Label = 'block comment'; Source = "<# comment  `n#>"; Count = 1 }
    ) {
        #=== Arrange ===#
        $Document = New-AstDocument -InputObject $Source
        $Document.Root.ParseErrors | Should -HaveCount 0
        $Rule = New-Nitpick -Callable Measure-AvoidTrailingWhitespace

        #=== Act ===#
        $Findings = @($Rule.Invoke($Document))

        #=== Assert ===#
        $Findings | Should -HaveCount $Count
        if ($Count -eq 0) {
            (Resolve-AstDocument -Document $Document -PassThruText).RenderedText |
                Should -BeExactly $Source
        }
    }

    It 'supports standalone diagnostic invocation without a Context document' {
        #=== Arrange ===#
        $Ast = [Parser]::ParseInput('$Value = 1  ', [ref] $null, [ref] $null)

        #=== Act ===#
        $Findings = @(Test-AvoidTrailingWhitespace -ScriptBlockAst $Ast)

        #=== Assert ===#
        $Findings | Should -HaveCount 1
        $Findings[0].GetType().Name | Should -Be 'DiagnosticRecord'
        $Findings[0].Extent.StartColumnNumber | Should -Be 11
        $Findings[0].SuggestedCorrections | Should -HaveCount 1
    }

    It 'discovers the document implementation without registering its ScriptAnalyzer adapter' {
        $Rule = @(Find-Nitpick -IncludeRule 'Nitpick/AvoidTrailingWhitespace')

        $Rule | Should -HaveCount 1
        $Rule[0].DispatchType.Name | Should -BeExactly 'AstDocument'
        $Rule[0].Callable.Name | Should -BeExactly 'Measure-AvoidTrailingWhitespace'
        (Test-AvoidTrailingWhitespace -Details).Name | Should -BeExactly 'AvoidTrailingWhitespace'
    }

    It 'reports but does not automatically correct malformed snapshots' {
        #=== Arrange ===#
        $Document = New-AstDocument -InputObject "if (  `n"
        $Rule = New-Nitpick -Callable Measure-AvoidTrailingWhitespace

        #=== Act ===#
        $Findings = @($Rule.Invoke($Document))

        #=== Assert ===#
        $Document.Root.ParseErrors.Count | Should -BeGreaterThan 0
        $Findings | Should -HaveCount 1
        $Findings[0].Corrections | Should -BeNullOrEmpty
    }

    It 'analyzes nested scopes once in native mode and only its scope for standalone calls' {
        #=== Arrange ===#
        $Source = '$Outer = 1  ' + "`n& {`n" + '$Inner = 2  ' + "`n}"

        #=== Act ===#
        $Root = [Parser]::ParseInput($Source, [ref] $null, [ref] $null)
        $Rule = New-Nitpick -Callable Measure-AvoidTrailingWhitespace

        #=== Assert ===#
        @($Rule.Invoke($Root)) | Should -HaveCount 2
        @(Test-AvoidTrailingWhitespace -ScriptBlockAst $Root) | Should -HaveCount 1
        $Nested = $Root.Find({ param($Node) $Node -is [ScriptBlockExpressionAst] }, $true).ScriptBlock
        @(Test-AvoidTrailingWhitespace -ScriptBlockAst $Nested) | Should -HaveCount 1
    }

    It 'edits only the submitted fragment and retains source provenance' {
        #=== Arrange ===#
        $Source = "# outside  `r`n& {`r`n" + '$Inner = 2  ' + "`r`n}`r`n# after  "
        $File = Join-Path $TestDrive 'Fragment.ps1'
        $Root = [Parser]::ParseInput($Source, $File, [ref] $null, [ref] $null)
        $Nested = $Root.Find({ param($Node) $Node -is [ScriptBlockExpressionAst] }, $true).ScriptBlock
        $Document = New-AstDocument -InputObject $Nested
        $Rule = New-Nitpick -Callable Measure-AvoidTrailingWhitespace

        #=== Act ===#
        $Findings = @($Rule.Invoke($Document))

        #=== Assert ===#
        $Findings | Should -HaveCount 1
        $Findings[0].ViolationExtent.File | Should -BeExactly $File
        $Findings[0].ViolationExtent.StartLineNumber | Should -Be 3
        $Proposal = Resolve-NitpickCorrectionProposal `
            -Document $Document `
            -Finding $Findings `
            -Rule $Rule

        $Proposal.CandidateText | Should -BeExactly ($Source.Replace('$Inner = 2  ', '$Inner = 2'))
        $Proposal.CandidateFindings | Should -HaveCount 0
    }

    It 'runs initial analysis and file correction reanalysis through Start-Nitpicking' {
        #=== Arrange ===#
        $Path = Join-Path $TestDrive 'Trailing.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 1  ' + "`r`n")

        #=== Act ===#
        $Results = @(Start-Nitpicking `
            -Path $Path `
            -IncludeRule Nitpick/AvoidTrailingWhitespace `
            -FixMode Apply `
            -Output Object `
            -Confirm:$false `
            -ErrorAction Stop
        )

        #=== Assert ===#
        $Result = $Results | Where-Object { $_.PSTypeNames -contains 'NitpickCorrectionResult' }
        $Result.Application.Status | Should -Be 'Written'
        $Result.Proposal.WasReanalyzed | Should -BeTrue
        $Result.Report.EffectiveFindings | Should -HaveCount 0
        [System.IO.File]::ReadAllText($Path) | Should -BeExactly ('$Value = 1' + "`r`n")
    }
}
