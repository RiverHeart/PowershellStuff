using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot\..\..\AstEditor.psd1" -Force

    <#
    .SYNOPSIS
        Creates a snapshot-backed document for the first scriptblock literal.
    #>
    function New-FragmentDocument {
        param (
            [string] $Text = '# host comment' + "`r`n" + '& { $Value = 1 }' + "`r`n" + '$Outside = 2',
            [string] $File = (Join-Path $TestDrive 'Fragment.ps1')
        )

        $Root = [Parser]::ParseInput($Text, $File, [ref] $null, [ref] $null)
        $Fragment = $Root.Find({
            param($Node)
            $Node -is [ScriptBlockExpressionAst]
        }, $true).ScriptBlock
        New-AstDocument -InputObject $Fragment
    }

    if (-not ('AstEditorTests.MismatchedExtent' -as [type])) {
        Add-Type -TypeDefinition @'
using System.Management.Automation.Language;
namespace AstEditorTests {
    public sealed class MismatchedExtent : IScriptExtent {
        private readonly IScriptExtent inner;
        public MismatchedExtent(IScriptExtent inner) { this.inner = inner; }
        public string File { get { return inner.File; } }
        public IScriptPosition StartScriptPosition { get { return inner.StartScriptPosition; } }
        public IScriptPosition EndScriptPosition { get { return inner.EndScriptPosition; } }
        public int StartLineNumber { get { return inner.StartLineNumber; } }
        public int StartColumnNumber { get { return inner.StartColumnNumber; } }
        public int EndLineNumber { get { return inner.EndLineNumber; } }
        public int EndColumnNumber { get { return inner.EndColumnNumber; } }
        public int StartOffset { get { return inner.StartOffset; } }
        public int EndOffset { get { return inner.EndOffset; } }
        public string Text { get { return inner.Text + "different"; } }
    }
}
'@
    }
}

AfterAll {
    Remove-Module AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'Snapshot-backed fragment documents' {
    It 'keeps root input and string input unfragmented, including empty text' -ForEach @(
        @{ Text = '' }
        @{ Text = 'param($Value)' }
    ) {
        $Root = [Parser]::ParseInput($Text, [ref] $null, [ref] $null)

        foreach ($InputObject in @($Text, $Root, [scriptblock]::Create($Text))) {
            $Document = New-AstDocument -InputObject $InputObject
            $Document.IsFragment | Should -BeFalse
            [object]::ReferenceEquals($Document.Ast, $Document.Root.Ast) | Should -BeTrue
            [object]::ReferenceEquals($Document.Tokens, $Document.Root.Tokens) | Should -BeTrue
            $Document.OriginalText | Should -BeExactly $Text

            $Result = Resolve-AstDocument -Document $Document -PassThruText
            $Result.RenderedText | Should -BeExactly $Text
            $Result.RenderedFragmentText | Should -BeExactly $Text
            $Result.ParseErrorCount | Should -Be 0
        }
    }

    It 'keeps file roots file-backed and unfragmented' {
        $Path = Join-Path $TestDrive 'FileRoot.ps1'
        [System.IO.File]::WriteAllText($Path, '$Value = 1')
        $Document = New-AstDocument -Path $Path

        $Document.IsFileBacked | Should -BeTrue
        $Document.IsFragment | Should -BeFalse
        [object]::ReferenceEquals($Document.Ast, $Document.Root.Ast) | Should -BeTrue
        [object]::ReferenceEquals($Document.Tokens, $Document.Root.Tokens) | Should -BeTrue
    }

    It 'distinguishes a root and a literal that share type and extent' -ForEach @(
        @{ Text = '{}' }
        @{ Text = '{ param($Value) }' }
    ) {
        $Document = New-FragmentDocument -Text $Text

        $Document.IsFragment | Should -BeTrue
        $Document.Ast.GetType() | Should -Be $Document.Root.Ast.GetType()
        $Document.Ast.Extent.StartOffset | Should -Be $Document.Root.Ast.Extent.StartOffset
        $Document.Ast.Extent.EndOffset | Should -Be $Document.Root.Ast.Extent.EndOffset
        $Document.Ast.Parent | Should -Not -BeNullOrEmpty
        $Document.Root.Ast.Parent | Should -BeNullOrEmpty

        $Result = Resolve-AstDocument -Document $Document -PassThruText
        $Result.ParseErrorCount | Should -Be 0
        $Result.RenderedFragmentText | Should -BeExactly $Text
    }

    It 'retains snapshot coordinates without inventing a console file' {
        $Text = 'Start-Nitpicking -Script { $Value = 1 } -FixMode Apply'
        $Document = New-FragmentDocument -Text $Text -File ''

        $Document.Ast.Extent.StartLineNumber | Should -Be 1
        $Document.Ast.Extent.StartColumnNumber | Should -Be 26
        $Document.Ast.Extent.File | Should -BeNullOrEmpty
        $Document.HasSourceProvenance() | Should -BeFalse
        $Document.OriginalText | Should -BeExactly $Text
        (Resolve-AstDocument -Document $Document -PassThruText).RenderedFragmentText |
            Should -BeExactly '{ $Value = 1 }'
    }

    It 'keeps only fragment tokens but retains all snapshot tokens and nested blocks' {
        $Text = "# outside`r`n& { # inside`r`n& { `$Value = 1 }`r`n}`r`n# after"
        $Document = New-FragmentDocument -Text $Text

        @($Document.Tokens | Where-Object { $_.Kind -eq [TokenKind]::Comment }).Text |
            Should -BeExactly '# inside'

        @($Document.Root.Tokens | Where-Object { $_.Kind -eq [TokenKind]::Comment }) |
            Should -HaveCount 3

        @($Document.Tokens | Where-Object {
            $_.Extent.StartOffset -lt $Document.Ast.Extent.StartOffset -or
            $_.Extent.EndOffset -gt $Document.Ast.Extent.EndOffset
        }) | Should -HaveCount 0

        @($Document.Ast.FindAll({
            param($Node)
            $Node -is [ScriptBlockAst]
        }, $true)) | Should -HaveCount 2

        $Document.NewLineSequence | Should -BeExactly "`r`n"
        $Document.OriginalFingerprint | Should -Be (
            New-AstDocument -InputObject $Text
        ).OriginalFingerprint
    }

    It 'accepts arbitrary AST node types even when they cover the whole snapshot' {
        $Text = 'function Get-Value { 1 }'
        $Root = [Parser]::ParseInput($Text, [ref] $null, [ref] $null)
        $Document = New-AstDocument -InputObject $Root.EndBlock.Statements[0]

        $Document.Ast | Should -BeOfType ([FunctionDefinitionAst])
        $Document.IsFragment | Should -BeTrue
        $Document.Ast.Extent.Text | Should -BeExactly $Text
        (Resolve-AstDocument -Document $Document).ParseErrorCount | Should -Be 0
    }

    It 'finds fragment tokens nested inside an expandable string without widening the root token view' {
        $Comment = "<#`r`n.SYNOPSIS Fragment help`r`n#>"
        $Text = '"$(& { ' + $Comment + "`r`n" + 'function Get-Value { 1 } })"'
        $Document = New-FragmentDocument -Text $Text

        $Document.Root.Tokens[0] | Should -BeOfType ([StringExpandableToken])
        @($Document.Tokens | Where-Object { $_.Kind -eq [TokenKind]::Comment }).Text |
            Should -BeExactly $Comment

        $Plan = Extract-AstFunction -Document $Document -Name Get-Value
        $Plan.IncludedHelp | Should -BeTrue

        $Result = Resolve-AstDocument -Document $Document -PassThruText
        $Result.ParseErrorCount | Should -Be 0
        $Result.RenderedFragmentText | Should -BeExactly '{  }'
    }

    It 'uses extent text when a hand-built extent has no full source' {
        $Extent = [ScriptExtent]::new(
            [ScriptPosition]::new($null, 1, 1, 'abc'),
            [ScriptPosition]::new($null, 1, 4, 'abc')
        )
        $Node = [StringConstantExpressionAst]::new($Extent, 'abc', [StringConstantType]::BareWord)

        $Document = New-AstDocument -InputObject $Node

        $Document.OriginalText | Should -BeExactly 'abc'
        $Document.IsFragment | Should -BeFalse
        $Document.Path | Should -Be '<memory>'
        $Document.IsFileBacked | Should -BeFalse
    }

    It 'rejects an extent that disagrees with its non-null snapshot' {
        $Root = [Parser]::ParseInput('abc', [ref] $null, [ref] $null)
        $Extent = New-Object AstEditorTests.MismatchedExtent -ArgumentList $Root.Extent
        $Node = [StringConstantExpressionAst]::new($Extent, 'abc', [StringConstantType]::BareWord)

        { New-AstDocument -InputObject $Node } | Should -Throw '*does not match its source snapshot*'
    }

    It 'rejects an input node that cannot be found by type, extent, and depth' {
        $Document = New-FragmentDocument
        $Detached = $Document.Ast.Copy()

        { New-AstDocument -InputObject $Detached } | Should -Throw '*Could not uniquely locate*'
    }

    It 'does not reread or enable implicit writes to the original file' {
        $Path = Join-Path $TestDrive 'StaleHost.ps1'
        [System.IO.File]::WriteAllText($Path, "# old`r`n& { `$Value = 1 }")
        $Root = [Parser]::ParseFile($Path, [ref] $null, [ref] $null)
        [System.IO.File]::WriteAllText($Path, '# changed on disk')

        $Fragment = $Root.Find({
            param($Node)
            $Node -is [ScriptBlockExpressionAst]
        }, $true).ScriptBlock
        $Document = New-AstDocument -InputObject $Fragment

        $Document.OriginalText | Should -BeExactly "# old`r`n& { `$Value = 1 }"
        $Document.IsFileBacked | Should -BeFalse
        $Document.Path | Should -Be '<memory>'

        $Before = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path))

        $Result = Save-AstDocument -Document $Document -Confirm:$false
        $Result.WriteStatus | Should -Be 'InvalidTarget'
        $Result.WasWritten | Should -BeFalse

        [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Path)) |
            Should -BeExactly $Before
    }
}

Describe 'Fragment edit boundaries and rendering' {
    It 'shows snapshot line numbers for a fragment diff' {
        $Document = New-FragmentDocument
        $Assignment = $Document.Ast.EndBlock.Statements[0]
        $Document.Replace($Assignment, '$Value = 200', 'Update value')

        $Diff = Show-AstDiff -Document $Document -Label Position -NoColor

        $Diff | Should -Match '2:5'
        $Diff | Should -Match '2 \| - & \{ \$Value = 1 \}'
        $Diff | Should -Not -Match '\$Outside'
    }

    It 'validates mixed length edits using the delta of the entire queued batch' {
        $Document = New-FragmentDocument -Text '& { $First = 1; $Second = 2 }'
        $First, $Second = $Document.Ast.EndBlock.Statements
        $Document.Replace($First, '$First = 123456', 'Longer')
        $Document.Replace($Second, '$S = 2', 'Shorter')

        $Result = Resolve-AstDocument -Document $Document -PassThruText

        $Result.ParseErrorCount | Should -Be 0
        $Result.RenderedFragmentText | Should -BeExactly '{ $First = 123456; $S = 2 }'
    }

    It 'rejects a complete batch containing an out-of-fragment edit without disturbing queued edits' {
        $Document = New-FragmentDocument
        $Start = $Document.Ast.Extent.StartOffset
        $Document.Insert($Start + 1, ' ', 'Already queued')
        $Inside = New-AstTextEdit `
            -Document $Document `
            -StartOffset ($Start + 2) `
            -EndOffset ($Start + 8) `
            -ReplacementText '$Other' `
            -Reason 'Inside'

        $Outside = New-AstTextEdit `
            -Document $Document `
            -StartOffset 0 `
            -EndOffset 1 `
            -ReplacementText '#' `
            -Reason 'Outside'

        $Caught = $null
        try {
            $null = Add-AstTextEdit -Document $Document -TextEdit @($Inside, $Outside)
        } catch {
            $Caught = $_
        }

        $Caught | Should -Not -BeNullOrEmpty
        $Caught.Exception.Data['FailureKind'] | Should -Be 'OutsideTarget'
        $Caught.Exception.Data['IncomingEdit'].Reason | Should -Be 'Outside'
        $Document.Edits | Should -HaveCount 1
        $Document.Edits[0].Reason | Should -Be 'Already queued'
    }

    It 'rejects direct document edits outside either fragment boundary' {
        $Document = New-FragmentDocument

        { $Document.Insert($Document.Ast.Extent.StartOffset - 1, ' ', 'Before') } |
            Should -Throw '*outside the submitted fragment*'

        { $Document.ReplaceRange(
            $Document.Ast.Extent.EndOffset,
            $Document.Ast.Extent.EndOffset + 1, '', 'After'
        ) } |
            Should -Throw '*outside the submitted fragment*'

        $Document.Edits | Should -HaveCount 0
    }

    It 'allows insertions at both boundaries and uses their net delta for the slice' {
        $Document = New-FragmentDocument
        $Document.Insert($Document.Ast.Extent.StartOffset, ' ', 'Start')
        $Document.Insert($Document.Ast.Extent.EndOffset, ' ', 'End')
        $Result = Resolve-AstDocument -Document $Document -PassThruText

        $Result.RenderedFragmentText | Should -BeExactly ' { $Value = 1 } '
        $Result.RenderedText | Should -BeExactly "# host comment`r`n&  { `$Value = 1 } `r`n`$Outside = 2"
        $Result.ParseErrorCount | Should -BeGreaterThan 0
        $Result.ParseErrors.ErrorId | Should -Contain 'FragmentNotFound'
    }

    It 'renders length-changing edits and whole-fragment replacements in snapshot coordinates' -ForEach @(
        @{ Replacement = '{ $Value = 12345 }' }
        @{ Replacement = '{}' }
    ) {
        $Document = New-FragmentDocument
        $null = Add-AstTextEdit `
            -Document $Document `
            -Extent $Document.Ast.Extent `
            -ReplacementText $Replacement `
            -Reason 'Replace fragment'

        $Result = Resolve-AstDocument -Document $Document -PassThruText

        $Result.ParseErrorCount | Should -Be 0
        $Result.RenderedFragmentText | Should -BeExactly $Replacement
        $Result.RenderedText | Should -BeExactly ("# host comment`r`n& $Replacement`r`n`$Outside = 2")
        $Document.Ast.Extent.Text | Should -BeExactly '{ $Value = 1 }'
    }

    It 'does not pretend a parseable replacement of another node type is the original fragment' {
        $Document = New-FragmentDocument
        $Document.Replace($Document.Ast, "'a string'", 'Change node type')

        $Result = Resolve-AstDocument -Document $Document -PassThruText

        $Result.ParseErrorCount | Should -Be 1
        $Result.ParseErrors[0].ErrorId | Should -Be 'FragmentNotFound'
        $Result.ParseErrors[0].Extent.File | Should -Be $Document.Ast.Extent.File
        $Result.RenderedFragmentText | Should -BeExactly "'a string'"
    }

    It 'does not filter render-validation errors outside a fragment' {
        $Document = New-FragmentDocument -Text "} `r`n& { `$Value = 1 }"
        $Document.ParseErrors | Should -HaveCount 0

        $Result = Resolve-AstDocument -Document $Document

        $Result.ParseErrorCount | Should -BeGreaterThan 0
        $Result.ParseErrors[0].Extent.StartOffset | Should -BeLessThan $Document.Ast.Extent.StartOffset
        $Result.ParseErrors[0].Extent.File | Should -Be $Document.Ast.Extent.File
        $Result.PSObject.Properties.Name | Should -Not -Contain 'RenderedText'
        $Result.PSObject.Properties.Name | Should -Not -Contain 'RenderedFragmentText'
    }
}

Describe 'Fragment parse diagnostics' {
    It 'filters only errors positioned before the fragment start' -ForEach @(
        @{ Text = "} `r`n& { `$Value = 1 }"; RelevantCount = 0 }
        @{ Text = "& { `$Value = 1 }`r`n}"; RelevantCount = 1 }
    ) {
        $Document = New-FragmentDocument -Text $Text

        $Document.Root.ParseErrors.Count | Should -BeGreaterThan 0
        $Document.ParseErrors | Should -HaveCount $RelevantCount
        @($Document.ParseErrors | Where-Object {
            $_.Extent.StartOffset -lt $Document.Ast.Extent.StartOffset
        }) | Should -HaveCount 0
    }

    It 'reports errors in a broken fragment even when it still relocates' {
        $Document = New-FragmentDocument -Text "`$x = 1`r`n`$sb = { if (`$true) { 1 }"

        $Document.IsFragment | Should -BeTrue
        $Document.Ast.Extent.EndOffset | Should -Be $Document.OriginalText.Length
        $Document.ParseErrors.Count | Should -BeGreaterThan 0
    }
}
