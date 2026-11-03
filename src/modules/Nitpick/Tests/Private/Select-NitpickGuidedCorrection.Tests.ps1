using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../Nitpick.psd1') -Force

    function New-GuidedFixture {
        param (
            [string] $Body = 'param([Parameter(Mandatory=$true)] $MyParam)',
            [switch] $Nested,
            [switch] $InMemory
        )

        $Path = Join-Path $TestDrive "Guided-$([guid]::NewGuid().ToString('N')).ps1"
        $Document = if ($InMemory) {
            New-AstDocument -InputObject $Body
        } elseif ($Nested) {
            [System.IO.File]::WriteAllText($Path, "# prefix`r`n& {$Body}")
            $Tokens = $null
            $Errors = $null
            $Root = [Parser]::ParseFile($Path, [ref] $Tokens, [ref] $Errors)
            $Fragment = $Root.Find({ param($Node) $Node -is [ScriptBlockExpressionAst] }, $true).ScriptBlock
            New-AstDocument -InputObject $Fragment
        } else {
            [System.IO.File]::WriteAllText($Path, $Body)
            New-AstDocument -Path $Path
        }

        $Rule = New-Nitpick -Callable Test-AvoidParameterAttributeBool
        $Findings = @($Rule.Invoke($Document.Ast))
        $Template = $Findings[0].Corrections[0]
        $Corrections = @(
            foreach ($Applicability in 'Safe', 'Unsafe') {
                New-NitpickCorrection `
                    -TextEdit $Template.TextEdits `
                    -FilePathOrContext $Path `
                    -Description "$Applicability alternative" `
                    -Applicability $Applicability `
                    -RuleId 'Nitpick/AvoidParameterAttributeBool'
            }
        )

        [pscustomobject]@{
            Path = $Path
            Document = $Document
            Finding = $Findings[0]
            Corrections = $Corrections
        }
    }
}

AfterAll {
    Remove-Module Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Select-NitpickGuidedCorrection' {
    BeforeEach {
        $Module = Get-Module Nitpick
        $PreviousEditor = & $Module { Get-Variable PSEditor -Scope Script -ErrorAction SilentlyContinue }
        $EditorContext = [pscustomobject]@{ Selections = [System.Collections.Generic.List[object]]::new() }
        $EditorContext | Add-Member ScriptMethod SetSelection {
            param($StartLine, $StartColumn, $EndLine, $EndColumn)
            $this.Selections.Add(@($StartLine, $StartColumn, $EndLine, $EndColumn))
        }
        $Workspace = [pscustomobject]@{ OpenedPaths = [System.Collections.Generic.List[string]]::new() }
        $Workspace | Add-Member ScriptMethod OpenFile { param($Path) $this.OpenedPaths.Add($Path) }
        $Editor = [pscustomobject]@{ Workspace = $Workspace; Context = $EditorContext }
        $Editor | Add-Member ScriptMethod GetEditorContext { $this.Context }
        & $Module { param($Editor) $script:PSEditor = $Editor } $Editor

        $Answers = [System.Collections.Generic.Queue[object]]::new()
        Mock Read-Host -ModuleName Nitpick { $Answers.Dequeue() }
        Mock Write-Host -ModuleName Nitpick { }
    }

    AfterEach {
        & $Module {
            param($Previous)
            if ($Previous) {
                Set-Variable PSEditor -Scope Script -Value $Previous.Value
            } else {
                Remove-Variable PSEditor -Scope Script -ErrorAction SilentlyContinue
            }
        } $PreviousEditor
    }

    It 'selects the violation range of a <Label> document in one-based source coordinates' -ForEach @(
        @{ Label = 'complete file'; Nested = $false }
        @{ Label = 'nested fragment'; Nested = $true }
    ) {
        $Fixture = New-GuidedFixture -Nested:$Nested
        $Answers.Enqueue('0')
        $Tokens = $null
        $Errors = $null
        $Original = [Parser]::ParseFile($Fixture.Path, [ref] $Tokens, [ref] $Errors).Find({
            param($Node)
            $Node.Extent.Text -ceq $Fixture.Finding.ViolationExtent.Text
        }, $true).Extent

        $Chosen = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture } {
            param($Fixture)
            Select-NitpickGuidedCorrection -Finding $Fixture.Finding -Correction $Fixture.Corrections -Document $Fixture.Document
        }

        [object]::ReferenceEquals($Chosen, $Fixture.Corrections[0]) | Should -BeTrue
        $Workspace.OpenedPaths | Should -Be @($Fixture.Path)
        $EditorContext.Selections | Should -HaveCount 1
        ($EditorContext.Selections[0] -join ',') | Should -Be (
            @($Original.StartLineNumber, $Original.StartColumnNumber, $Original.EndLineNumber, $Original.EndColumnNumber) -join ','
        )
        $Fixture.Document.IsFileBacked | Should -Be (-not $Nested)
    }

    It 'does not navigate without <Label> but still prompts' -ForEach @(
        @{ Label = 'source provenance'; InMemory = $true; HasEditor = $true }
        @{ Label = 'Editor Services'; InMemory = $false; HasEditor = $false }
    ) {
        $Fixture = New-GuidedFixture -InMemory:$InMemory
        if (-not $HasEditor) {
            & $Module { $script:PSEditor = $null }
        }
        $Answers.Enqueue('1')

        $Chosen = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture } {
            param($Fixture)
            Select-NitpickGuidedCorrection -Finding $Fixture.Finding -Correction $Fixture.Corrections -Document $Fixture.Document
        }

        [object]::ReferenceEquals($Chosen, $Fixture.Corrections[1]) | Should -BeTrue
        $Workspace.OpenedPaths | Should -HaveCount 0
        $EditorContext.Selections | Should -HaveCount 0
        Should -Invoke Read-Host -ModuleName Nitpick -Times 1 -Exactly
    }

    It 'warns and still prompts when navigation fails' {
        $Fixture = New-GuidedFixture
        $Workspace | Add-Member ScriptMethod OpenFile { throw 'editor unavailable' } -Force
        $Answers.Enqueue('0')

        $WarningMessages = @(InModuleScope Nitpick -Parameters @{ Fixture = $Fixture } {
            param($Fixture)
            $null = Select-NitpickGuidedCorrection `
                -Finding $Fixture.Finding `
                -Correction $Fixture.Corrections `
                -Document $Fixture.Document `
                -WarningVariable Warnings 3>$null
            @($Warnings | ForEach-Object { $_.Message })
        })

        $WarningMessages | Should -HaveCount 1
        $WarningMessages[0] | Should -Match 'Could not navigate.*editor unavailable'
        Should -Invoke Read-Host -ModuleName Nitpick -Times 1 -Exactly
    }

    It 'lists non-Safe applicability in the prompt' {
        $Fixture = New-GuidedFixture
        $Answers.Enqueue('0')

        $null = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture } {
            param($Fixture)
            Select-NitpickGuidedCorrection -Finding $Fixture.Finding -Correction $Fixture.Corrections -Document $Fixture.Document
        }

        Should -Invoke Write-Host -ModuleName Nitpick -ParameterFilter { $Object -like '*`[0`] Safe alternative' } -Times 1
        Should -Invoke Write-Host -ModuleName Nitpick -ParameterFilter { $Object -like '*`[1`] (Unsafe) Unsafe alternative' } -Times 1
    }

    It 'rejects out-of-range and non-numeric answers until a valid index is entered' {
        $Fixture = New-GuidedFixture
        foreach ($Answer in '20', '1x', '-1', '2', ' 1') {
            $Answers.Enqueue($Answer)
        }

        $Chosen = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture } {
            param($Fixture)
            Select-NitpickGuidedCorrection -Finding $Fixture.Finding -Correction $Fixture.Corrections -Document $Fixture.Document
        }

        [object]::ReferenceEquals($Chosen, $Fixture.Corrections[1]) | Should -BeTrue
        Should -Invoke Read-Host -ModuleName Nitpick -Times 5 -Exactly
    }

    It 'returns nothing on a <Label> answer instead of looping' -ForEach @(
        @{ Label = 'blank'; Answer = '' }
        @{ Label = 'whitespace'; Answer = '   ' }
        @{ Label = 'null (end of input)'; Answer = $null }
    ) {
        $Fixture = New-GuidedFixture
        $Answers.Enqueue($Answer)

        $Chosen = InModuleScope Nitpick -Parameters @{ Fixture = $Fixture } {
            param($Fixture)
            Select-NitpickGuidedCorrection -Finding $Fixture.Finding -Correction $Fixture.Corrections -Document $Fixture.Document
        }

        $Chosen | Should -BeNullOrEmpty
        Should -Invoke Read-Host -ModuleName Nitpick -Times 1 -Exactly
    }
}
