using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Shared fixtures for correction-selection tests.

.DESCRIPTION
    Dot-source from a test file's BeforeAll after importing Nitpick:

        . (Join-Path $PSScriptRoot '../../Support/CorrectionFixtures.ps1')

    The helpers build documents with known provenance, findings that offer several
    alternative corrections, registered rules that emit alternatives through
    Start-Nitpicking, and a fake PowerShell Editor Services object. They rely on
    $TestDrive and on Nitpick's public commands being imported into the caller's
    session, which is why they are dot-sourced rather than packaged as a module.

    Invariant: every alternative on a finding is a distinct object. The selector
    identifies the chosen correction by reference, so reusing one object twice would
    make a choice ambiguous. New-TestChoiceFinding guarantees this and
    Assert-TestCorrectionsDistinct makes the check available to hand-built fixtures.
#>

<#
.SYNOPSIS
    Creates an AstDocument whose source provenance is known.

.PARAMETER Source
    Script text analyzed by rules. For Nested, this is the body of a scriptblock
    expression embedded in the file after Prefix.

.PARAMETER Kind
    File: a file-backed document (IsFileBacked, Path = file).
    Nested: an in-memory document parsed from a ScriptBlockAst found inside a file,
    whose extents retain snapshot-absolute file and line/column positions.
    String: an in-memory document with no provenance.

.PARAMETER Prefix
    Text placed before the nested scriptblock. Defaults to a comment line so the
    fragment starts on line 2.

.PARAMETER Name
    File name inside $TestDrive. Defaults to a unique name.

.EXAMPLE
    $Fixture = New-TestSourceDocument -Kind Nested
    $Fixture.Document.Ast.Extent.File  # Source file, not a save target
    $Fixture.Document.IsFileBacked    # False
#>
function New-TestSourceDocument {
    [CmdletBinding()]
    param (
        [string] $Source = 'param([Parameter(Mandatory=$true)] $MyParam)',

        [ValidateSet('File', 'Nested', 'String')]
        [string] $Kind = 'File',

        [string] $Prefix = "# prefix`r`n",

        [string] $Name
    )

    if (-not $Name) {
        $Name = "$Kind-$([guid]::NewGuid().ToString('N')).ps1"
    }
    $Path = Join-Path $TestDrive $Name

    $Fixture = [pscustomobject]@{
        Kind = $Kind
        Path = $null
        Source = $Source
        FileText = $null
        Document = $null
        RootAst = $null
        FragmentAst = $null
    }

    switch ($Kind) {
        'String' {
            $Fixture.Document = New-AstDocument -InputObject $Source
        }
        'File' {
            [System.IO.File]::WriteAllText($Path, $Source)
            $Fixture.Path = $Path
            $Fixture.FileText = $Source
            $Fixture.Document = New-AstDocument -Path $Path
            $Fixture.RootAst = $Fixture.Document.Ast
        }
        'Nested' {
            $FileText = "$Prefix& {$Source}"
            [System.IO.File]::WriteAllText($Path, $FileText)
            $Tokens = $null
            $Errors = $null
            $Root = [Parser]::ParseFile($Path, [ref] $Tokens, [ref] $Errors)
            $Expression = $Root.Find({ param($Node) $Node -is [ScriptBlockExpressionAst] }, $true)
            if (-not $Expression) {
                throw 'The nested fixture did not contain a scriptblock expression.'
            }

            $Fixture.Path = $Path
            $Fixture.FileText = $FileText
            $Fixture.RootAst = $Root
            $Fixture.FragmentAst = $Expression.ScriptBlock
            $Fixture.Document = New-AstDocument -InputObject $Expression.ScriptBlock
        }
    }

    return $Fixture
}

<#
.SYNOPSIS
    Throws when any two corrections are the same object.

.DESCRIPTION
    Guided selection identifies the chosen correction by reference, so a finding
    must never list one correction object twice as if it were two alternatives.
#>
function Assert-TestCorrectionsDistinct {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Correction
    )

    for ($i = 0; $i -lt $Correction.Count; $i++) {
        for ($j = $i + 1; $j -lt $Correction.Count; $j++) {
            if ([object]::ReferenceEquals($Correction[$i], $Correction[$j])) {
                throw "Corrections at index $i and $j are the same object; alternatives must be distinct."
            }
        }
    }
}

<#
.SYNOPSIS
    Produces a finding that offers several alternative corrections.

.DESCRIPTION
    Runs a rule against the fixture's document, takes its first finding, and
    replaces that finding's corrections with one distinct correction per requested
    applicability. Each alternative reuses the original correction's text edits, so
    every alternative is valid against the snapshot and they differ only in
    identity, description, and applicability. Returns the finding; its
    Corrections property holds the alternatives in the order requested.

.PARAMETER Fixture
    A fixture from New-TestSourceDocument, or any AstDocument.

.PARAMETER Applicability
    One entry per alternative. Defaults to two Safe alternatives, which is
    undecided under automatic selection.

.PARAMETER Callable
    The rule producer used to obtain the template finding. Must yield at least one
    finding with a correction against the fixture's source.

.PARAMETER RuleId
    Identity stamped on the alternatives.

.EXAMPLE
    $Fixture = New-TestSourceDocument
    $Finding = New-TestChoiceFinding -Fixture $Fixture -Applicability 'Safe', 'Unsafe'
    Resolve-NitpickCorrectionProposal -Document $Fixture.Document -Finding $Finding -CorrectionSelector {
        param($Finding, $Corrections) $Corrections[1]
    }
#>
function New-TestChoiceFinding {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Fixture,

        [ValidateSet('Safe', 'Review', 'Unsafe')]
        [string[]] $Applicability = @('Safe', 'Safe'),

        [string] $Callable = 'Test-AvoidParameterAttributeBool',

        [string] $RuleId = 'Nitpick/AvoidParameterAttributeBool'
    )

    $Document = if ($Fixture.PSObject.Properties['Document']) { $Fixture.Document } else { $Fixture }
    $Context = if ($Fixture.PSObject.Properties['Path'] -and $Fixture.Path) { $Fixture.Path } else { '<ScriptBlock>' }

    $Rule = New-Nitpick -Callable $Callable
    $Findings = @($Rule.Invoke($Document.Ast))
    if ($Findings.Count -eq 0 -or $Findings[0].Corrections.Count -eq 0) {
        throw "Rule '$Callable' produced no correctable finding against the fixture source."
    }

    $Finding = $Findings[0]
    $Template = $Finding.Corrections[0]
    $Index = 0
    $Alternatives = @(
        foreach ($Value in $Applicability) {
            New-NitpickCorrection `
                -TextEdit $Template.TextEdits `
                -FilePathOrContext $Context `
                -Description "$Value alternative $Index" `
                -Applicability $Value `
                -RuleId $RuleId
            $Index++
        }
    )

    Assert-TestCorrectionsDistinct -Correction $Alternatives
    $Finding.Corrections = $Alternatives
    return $Finding
}

<#
.SYNOPSIS
    Registers a rule that emits alternative corrections for one trigger statement.

.DESCRIPTION
    For Start-Nitpicking tests, where corrections must come from a registered rule
    rather than be swapped onto a finding. The rule matches a script whose first
    end-block statement text equals Trigger and emits one finding whose corrections
    replace that statement with each alternative's ReplacementText.

.PARAMETER Name
    Local rule name; the rule is registered under 'Local/<Name>'.

.PARAMETER Trigger
    Exact statement text that produces the finding, for example '$Choice = 1'.

.PARAMETER Alternative
    Ordered hashtables with ReplacementText and optional Applicability (default
    Safe) and Description.

.EXAMPLE
    Register-TestAlternativesRule -Name ChoiceRule -Trigger '$Choice = 1' -Alternative @(
        @{ ReplacementText = '$Choice = 2'; Applicability = 'Review' }
        @{ ReplacementText = '$Choice = 3'; Applicability = 'Unsafe' }
    )
    Start-Nitpicking -Path $Path -IncludeRule Local/ChoiceRule -FixMode Guided
#>
function Register-TestAlternativesRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $Trigger,

        [Parameter(Mandatory)]
        [hashtable[]] $Alternative,

        [string] $Severity = 'Warning'
    )

    $RuleId = "Local/$Name"
    $Rule = {
        param([ScriptBlockAst] $ScriptBlockAst)

        $Statement = $ScriptBlockAst.EndBlock.Statements | Select-Object -First 1
        if (-not $Statement -or $Statement.Extent.Text -ne $Trigger) {
            return
        }

        $Context = if ($Statement.Extent.File) { $Statement.Extent.File } else { '<ScriptBlock>' }
        $Index = 0
        $Corrections = @(
            foreach ($Entry in $Alternative) {
                $Applicability = if ($Entry.Applicability) { $Entry.Applicability } else { 'Safe' }
                $Description = if ($Entry.Description) { $Entry.Description } else { "$Applicability alternative $Index" }
                New-NitpickCorrection `
                    -ViolationExtent $Statement.Extent `
                    -ReplacementText $Entry.ReplacementText `
                    -FilePathOrContext $Context `
                    -Description $Description `
                    -Applicability $Applicability `
                    -RuleId $RuleId
                $Index++
            }
        )

        New-NitpickFinding `
            -RuleId $RuleId `
            -Message "Alternatives for $Trigger" `
            -ViolationExtent $Statement.Extent `
            -Severity $Severity `
            -ScriptPath $Context `
            -Corrections $Corrections `
            -Explanation 'Test rule offering alternative corrections.'
    }.GetNewClosure()

    Register-Nitpick -Callable $Rule -Name $Name -Source Tests
}

<#
.SYNOPSIS
    Builds a fake $psEditor that records navigation calls.

.DESCRIPTION
    Returns an object with the Editor Services surface Select-NitpickGuidedCorrection
    uses: Workspace.OpenFile(path) and GetEditorContext().SetSelection(l, c, l, c).
    Calls are recorded in Workspace.OpenedPaths and Context.Selections (each
    selection is @(StartLine, StartColumn, EndLine, EndColumn)).

.PARAMETER OpenFileThrows
    Makes OpenFile throw with this message, to test navigation failure handling.
#>
function New-TestPSEditor {
    [CmdletBinding()]
    param (
        [string] $OpenFileThrows
    )

    $Context = [pscustomobject]@{ Selections = [System.Collections.Generic.List[object]]::new() }
    $Context | Add-Member ScriptMethod SetSelection {
        param($StartLine, $StartColumn, $EndLine, $EndColumn)
        $this.Selections.Add(@($StartLine, $StartColumn, $EndLine, $EndColumn))
    }

    $Workspace = [pscustomobject]@{
        OpenedPaths = [System.Collections.Generic.List[string]]::new()
        FailureMessage = $OpenFileThrows
    }
    $Workspace | Add-Member ScriptMethod OpenFile {
        param($Path)
        if ($this.FailureMessage) { throw $this.FailureMessage }
        $this.OpenedPaths.Add($Path)
    }

    $Editor = [pscustomobject]@{ Workspace = $Workspace; Context = $Context }
    $Editor | Add-Member ScriptMethod GetEditorContext { $this.Context }
    return $Editor
}

<#
.SYNOPSIS
    Installs a fake $psEditor into the Nitpick module scope.

.DESCRIPTION
    Returns a state token for Restore-TestPSEditor. Pass $null as Editor to
    simulate running outside PowerShell Editor Services.
#>
function Set-TestPSEditor {
    [CmdletBinding()]
    param (
        [AllowNull()]
        [psobject] $Editor
    )

    $Module = Get-Module Nitpick
    $Previous = & $Module { Get-Variable PSEditor -Scope Script -ErrorAction SilentlyContinue }
    & $Module { param($Value) $script:PSEditor = $Value } $Editor

    return [pscustomobject]@{ HadVariable = [bool] $Previous; Value = $Previous.Value }
}

<#
.SYNOPSIS
    Reverts Set-TestPSEditor using its returned state token.
#>
function Restore-TestPSEditor {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $State
    )

    & (Get-Module Nitpick) {
        param($State)
        if ($State.HadVariable) {
            Set-Variable PSEditor -Scope Script -Value $State.Value
        } else {
            Remove-Variable PSEditor -Scope Script -ErrorAction SilentlyContinue
        }
    } $State
}
