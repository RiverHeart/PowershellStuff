
<#
.SYNOPSIS
    Creates a native Nitpick correction or a PSScriptAnalyzer correction extent.

.DESCRIPTION
    Creates an immutable description of a text correction. Line and column positions are
    one-based to preserve PSScriptAnalyzer CorrectionExtent compatibility. Native offsets
    are zero-based and end-exclusive. A correction describes a proposed edit but does not
    mutate a file; application belongs to a target-level correction coordinator.

    Extent-based corrections capture offsets and expected source text automatically.
    Direct offset construction is retained for compatibility but is deprecated; new callers
    should create a validated AstEditor edit and pass it through TextEdit. Corrections created only
    from line and column positions remain suitable for PSScriptAnalyzer interoperability
    but are not natively applicable until a later coordinator resolves them against source.

.PARAMETER ViolationExtent
    The source extent to describe. Its one-based line and column coordinates are copied to
    the correction.

.PARAMETER TextEdit
    A detached AstEditor edit whose coordinates, expected text, and replacement text are
    projected by the correction. The edit remains the authoritative source-edit object.

.PARAMETER StartLineNumber
    The one-based line on which the correction begins.

.PARAMETER EndLineNumber
    The one-based line on which the correction ends.

.PARAMETER StartColumnNumber
    The one-based column at which the correction begins.

.PARAMETER EndColumnNumber
    The one-based, end-exclusive column at which the correction ends.

.PARAMETER StartOffset
    The zero-based offset at which the correction begins.

.PARAMETER EndOffset
    The zero-based, end-exclusive offset at which the correction ends.

.PARAMETER ExpectedText
    The exact source text expected in an explicit offset range. Use an empty string for
    an insertion.

.PARAMETER Applicability
    Classifies the correction as Safe, Review, or Unsafe. The default is Safe.

.PARAMETER ChangeSetId
    An optional identifier shared by corrections that form one change set. Every correction
    in a change set is accepted or skipped together. IDs are target-wide, including across
    rules; include producer identity and occurrence unless that coupling is intentional.

.PARAMETER RuleName
    An optional stable identity for the rule that produced the correction.

.PARAMETER ReplacementText
    Text that replaces the described source range. An empty string represents deletion.

.PARAMETER FilePathOrContext
    The source file path, or an explicit context label such as <ScriptBlock> for in-memory
    source.

.PARAMETER Description
    A human-readable explanation of the proposed correction.

.PARAMETER OutputAs
    Returns a native NitpickCorrection by default, or a PSScriptAnalyzer CorrectionExtent
    when CorrectionExtent is selected.

.EXAMPLE
    $Extent = { $Value = 1 }.Ast.EndBlock.Statements[0].Extent
    New-NitpickCorrection `
        -ViolationExtent $Extent `
        -ReplacementText '$Value = 2' `
        -FilePathOrContext '<ScriptBlock>' `
        -Description 'Replace the assignment.'

    Creates a native correction whose offsets and expected text come from an AST extent.

.EXAMPLE
    New-NitpickCorrection `
        -StartLineNumber 1 -EndLineNumber 1 `
        -StartColumnNumber 10 -EndColumnNumber 11 `
        -StartOffset 9 -EndOffset 10 `
        -ExpectedText '1' -ReplacementText '2' `
        -FilePathOrContext '<ScriptBlock>' `
        -Description 'Replace the value.'

    Creates a replacement from an explicit zero-based, end-exclusive offset range.

.EXAMPLE
    New-NitpickCorrection `
        -StartLineNumber 1 -EndLineNumber 1 `
        -StartColumnNumber 1 -EndColumnNumber 1 `
        -StartOffset 0 -EndOffset 0 `
        -ExpectedText '' -ReplacementText '# generated' `
        -FilePathOrContext '<ScriptBlock>' `
        -Description 'Insert a header.'

    Creates a zero-width insertion. ExpectedText is empty because the range contains no text.

.EXAMPLE
    $First = New-NitpickCorrection `
        -ViolationExtent $FirstExtent `
        -ReplacementText '$First = 2' `
        -FilePathOrContext '<ScriptBlock>' `
        -Description 'Replace the first assignment.' `
        -ChangeSetId 'CoupledAssignments'
    $Second = New-NitpickCorrection `
        -ViolationExtent $SecondExtent `
        -ReplacementText '$Second = 3' `
        -FilePathOrContext '<ScriptBlock>' `
        -Description 'Replace the second assignment.' `
        -ChangeSetId 'CoupledAssignments'

    Creates two corrections in one change set. A coordinator accepts or skips both together.

.EXAMPLE
    New-NitpickCorrection `
        -StartLineNumber 1 -EndLineNumber 1 `
        -StartColumnNumber 1 -EndColumnNumber 11 `
        -ReplacementText '$Value = 2' `
        -FilePathOrContext 'Example.ps1' `
        -Description 'Replace the assignment.' `
        -OutputAs CorrectionExtent

    Creates a line-and-column-only PSScriptAnalyzer CorrectionExtent. Without native offsets,
    this form cannot be applied by the Nitpick correction coordinator.
#>
function New-NitpickCorrection {
    [CmdletBinding(DefaultParameterSetName = 'ByExtent')]
    [OutputType([object])]
    param(
        [Parameter(Mandatory,ParameterSetName='ByExtent')]
        [System.Management.Automation.Language.IScriptExtent] $ViolationExtent,

        [Parameter(Mandatory, ParameterSetName = 'ByTextEdit')]
        [ValidateScript({ $_.GetType().Name -eq 'AstTextEdit' })]
        [psobject] $TextEdit,

        [Parameter(Mandatory, ParameterSetName = 'ByLineAndColumn')]
        [Parameter(Mandatory, ParameterSetName = 'ByOffset')]
        [int] $StartLineNumber,

        [Parameter(Mandatory, ParameterSetName = 'ByLineAndColumn')]
        [Parameter(Mandatory, ParameterSetName = 'ByOffset')]
        [int] $EndLineNumber,

        [Parameter(Mandatory, ParameterSetName = 'ByLineAndColumn')]
        [Parameter(Mandatory, ParameterSetName = 'ByOffset')]
        [int] $StartColumnNumber,

        [Parameter(Mandatory, ParameterSetName = 'ByLineAndColumn')]
        [Parameter(Mandatory, ParameterSetName = 'ByOffset')]
        [int] $EndColumnNumber,

        [Parameter(Mandatory, ParameterSetName = 'ByOffset')]
        [int] $StartOffset,

        [Parameter(Mandatory, ParameterSetName = 'ByOffset')]
        [int] $EndOffset,

        [Parameter(Mandatory, ParameterSetName = 'ByOffset')]
        [AllowEmptyString()]
        [string] $ExpectedText,

        [Parameter(Mandatory,ParameterSetName='ByLineAndColumn')]
        [Parameter(Mandatory,ParameterSetName='ByExtent')]
        [Parameter(Mandatory, ParameterSetName = 'ByOffset')]
        [AllowEmptyString()]
        [string] $ReplacementText,

        [Parameter(Mandatory,ParameterSetName='ByLineAndColumn', HelpMessage = "File path or context for the correction extent.")]
        [Parameter(Mandatory,ParameterSetName='ByExtent', HelpMessage = "File path or context for the correction extent.")]
        [Parameter(Mandatory, ParameterSetName = 'ByOffset', HelpMessage = "File path or context for the correction extent.")]
        [Parameter(Mandatory, ParameterSetName = 'ByTextEdit', HelpMessage = "File path or context for the correction extent.")]
        [string] $FilePathOrContext,

        [Parameter(Mandatory,ParameterSetName='ByLineAndColumn', HelpMessage = "Description of the correction extent. Appears as hover text in the editor.")]
        [Parameter(Mandatory,ParameterSetName='ByExtent', HelpMessage = "Description of the correction extent. Appears as hover text in the editor.")]
        [Parameter(Mandatory, ParameterSetName = 'ByOffset', HelpMessage = "Description of the correction extent. Appears as hover text in the editor.")]
        [Parameter(Mandatory, ParameterSetName = 'ByTextEdit', HelpMessage = "Description of the correction extent. Appears as hover text in the editor.")]
        [ValidateNotNullOrEmpty()]
        [string] $Description,

        [ValidateSet('Safe', 'Review', 'Unsafe')]
        [string] $Applicability = 'Safe',

        [ValidateNotNullOrEmpty()]
        [string] $ChangeSetId,

        [ValidateNotNullOrEmpty()]
        [string] $RuleName,

        [Parameter(ParameterSetName='ByLineAndColumn', HelpMessage = "Specifies the output format for the correction extent.")]
        [Parameter(ParameterSetName='ByExtent', HelpMessage = "Specifies the output format for the correction extent.")]
        [Parameter(ParameterSetName = 'ByOffset', HelpMessage = "Specifies the output format for the correction extent.")]
        [Parameter(ParameterSetName = 'ByTextEdit', HelpMessage = "Specifies the output format for the correction extent.")]
        [ValidateSet('NitpickCorrection', 'CorrectionExtent')]
        [string] $OutputAs = 'NitpickCorrection'
    )

    $Correction = $null
    $CorrectionParams = @{
        FilePathOrContext = $FilePathOrContext
        Description = $Description
        Applicability = $Applicability
    }
    if ($PSCmdlet.ParameterSetName -eq 'ByExtent') {
        $CorrectionParams.TextEdit = New-AstTextEdit `
            -Extent $ViolationExtent `
            -ReplacementText $ReplacementText `
            -Reason $Description
    } elseif ($PSCmdlet.ParameterSetName -eq 'ByOffset') {
        $CorrectionParams.TextEdit = New-AstTextEdit `
            -StartLineNumber $StartLineNumber `
            -EndLineNumber $EndLineNumber `
            -StartColumnNumber $StartColumnNumber `
            -EndColumnNumber $EndColumnNumber `
            -StartOffset $StartOffset `
            -EndOffset $EndOffset `
            -ExpectedText $ExpectedText `
            -ReplacementText $ReplacementText `
            -Reason $Description
    } elseif ($PSCmdlet.ParameterSetName -eq 'ByTextEdit') {
        $CorrectionParams.TextEdit = $TextEdit
    } else {
        $CorrectionParams.StartLineNumber = $StartLineNumber
        $CorrectionParams.EndLineNumber = $EndLineNumber
        $CorrectionParams.StartColumnNumber = $StartColumnNumber
        $CorrectionParams.EndColumnNumber = $EndColumnNumber
        $CorrectionParams.ReplacementText = $ReplacementText
    }
    if ($PSBoundParameters.ContainsKey('ChangeSetId')) {
        $CorrectionParams.ChangeSetId = $ChangeSetId
    }
    if ($PSBoundParameters.ContainsKey('RuleName')) {
        $CorrectionParams.RuleName = $RuleName
    }
    $Correction = [NitpickCorrection]::new($CorrectionParams)

    if ($OutputAs -eq 'CorrectionExtent') {
        $Correction = $Correction.ToCorrectionExtent()
    }

    return $Correction
}
