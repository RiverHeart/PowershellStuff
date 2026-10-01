
<#
.SYNOPSIS
    Creates a new Nitpick correction extent for a given AST node.

.DESCRIPTION
    Creates an immutable description of a text correction. Line and column positions are
    one-based to preserve PSScriptAnalyzer CorrectionExtent compatibility. Native offsets
    are zero-based and end-exclusive. A correction describes a proposed edit but does not
    mutate a file; application belongs to a target-level correction coordinator.

    Extent-based corrections capture offsets and expected source text automatically.
    Explicit offset corrections require expected source text. Corrections created only
    from line and column positions remain suitable for PSScriptAnalyzer interoperability
    but are not natively applicable until a later coordinator resolves them against source.

.PARAMETER ViolationExtent
    The source extent to describe. Its one-based line and column coordinates are copied to
    the correction.

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

.PARAMETER GroupId
    An optional identifier shared by corrections that must later be applied atomically.

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
#>
function New-NitpickCorrection {
    [CmdletBinding(DefaultParameterSetName = 'ByExtent')]
    [OutputType([object])]
    param(
        [Parameter(Mandatory,ParameterSetName='ByExtent')]
        [System.Management.Automation.Language.IScriptExtent] $ViolationExtent,

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
        [string] $FilePathOrContext,

        [Parameter(Mandatory,ParameterSetName='ByLineAndColumn', HelpMessage = "Description of the correction extent. Appears as hover text in the editor.")]
        [Parameter(Mandatory,ParameterSetName='ByExtent', HelpMessage = "Description of the correction extent. Appears as hover text in the editor.")]
        [Parameter(Mandatory, ParameterSetName = 'ByOffset', HelpMessage = "Description of the correction extent. Appears as hover text in the editor.")]
        [ValidateNotNullOrEmpty()]
        [string] $Description,

        [ValidateSet('Safe', 'Review', 'Unsafe')]
        [string] $Applicability = 'Safe',

        [ValidateNotNullOrEmpty()]
        [string] $GroupId,

        [ValidateNotNullOrEmpty()]
        [string] $RuleName,

        [Parameter(ParameterSetName='ByLineAndColumn', HelpMessage = "Specifies the output format for the correction extent.")]
        [Parameter(ParameterSetName='ByExtent', HelpMessage = "Specifies the output format for the correction extent.")]
        [Parameter(ParameterSetName = 'ByOffset', HelpMessage = "Specifies the output format for the correction extent.")]
        [ValidateSet('NitpickCorrection', 'CorrectionExtent')]
        [string] $OutputAs = 'NitpickCorrection'
    )

    $Correction = $null
    $CorrectionParams = @{
        StartLineNumber = if ($ViolationExtent) { $ViolationExtent.StartLineNumber } else { $StartLineNumber }
        EndLineNumber = if ($ViolationExtent) { $ViolationExtent.EndLineNumber } else { $EndLineNumber }
        StartColumnNumber = if ($ViolationExtent) { $ViolationExtent.StartColumnNumber } else { $StartColumnNumber }
        EndColumnNumber = if ($ViolationExtent) { $ViolationExtent.EndColumnNumber } else { $EndColumnNumber }
        ReplacementText = $ReplacementText
        FilePathOrContext = $FilePathOrContext
        Description = $Description
        Applicability = $Applicability
    }
    if ($PSCmdlet.ParameterSetName -eq 'ByExtent') {
        $CorrectionParams.StartOffset = $ViolationExtent.StartOffset
        $CorrectionParams.EndOffset = $ViolationExtent.EndOffset
        $CorrectionParams.ExpectedText = $ViolationExtent.Text
    } elseif ($PSCmdlet.ParameterSetName -eq 'ByOffset') {
        $CorrectionParams.StartOffset = $StartOffset
        $CorrectionParams.EndOffset = $EndOffset
        $CorrectionParams.ExpectedText = $ExpectedText
    }
    if ($PSBoundParameters.ContainsKey('GroupId')) {
        $CorrectionParams.GroupId = $GroupId
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
