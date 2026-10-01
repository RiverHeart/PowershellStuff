
<#
.SYNOPSIS
    Creates a new Nitpick correction extent for a given AST node.

.DESCRIPTION
    Creates an immutable description of a text correction. Line and column positions are
    one-based to preserve PSScriptAnalyzer CorrectionExtent compatibility. A correction
    describes a proposed edit but does not mutate a file; application belongs to a
    target-level correction coordinator.

    Native offset-based application is not yet implemented. Corrections created only from
    line and column positions remain suitable for PSScriptAnalyzer interoperability.

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
    [CmdletBinding(DefaultParameterSetName='ByExtent')]
    [OutputType([object])]
    param(
        [Parameter(Mandatory,ParameterSetName='ByExtent')]
        [System.Management.Automation.Language.IScriptExtent] $ViolationExtent,

        [Parameter(Mandatory,ParameterSetName='ByLineAndColumn')]
        [int] $StartLineNumber,

        [Parameter(Mandatory,ParameterSetName='ByLineAndColumn')]
        [int] $EndLineNumber,

        [Parameter(Mandatory,ParameterSetName='ByLineAndColumn')]
        [int] $StartColumnNumber,

        [Parameter(Mandatory,ParameterSetName='ByLineAndColumn')]
        [int] $EndColumnNumber,

        [Parameter(Mandatory,ParameterSetName='ByLineAndColumn')]
        [Parameter(Mandatory,ParameterSetName='ByExtent')]
        [AllowEmptyString()]
        [string] $ReplacementText,

        [Parameter(Mandatory,ParameterSetName='ByLineAndColumn', HelpMessage = "File path or context for the correction extent.")]
        [Parameter(Mandatory,ParameterSetName='ByExtent', HelpMessage = "File path or context for the correction extent.")]
        [string] $FilePathOrContext,

        [Parameter(Mandatory,ParameterSetName='ByLineAndColumn', HelpMessage = "Description of the correction extent. Appears as hover text in the editor.")]
        [Parameter(Mandatory,ParameterSetName='ByExtent', HelpMessage = "Description of the correction extent. Appears as hover text in the editor.")]
        [ValidateNotNullOrEmpty()]
        [string] $Description,

        [Parameter(ParameterSetName='ByLineAndColumn', HelpMessage = "Specifies the output format for the correction extent.")]
        [Parameter(ParameterSetName='ByExtent', HelpMessage = "Specifies the output format for the correction extent.")]
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
    }
    $Correction = [NitpickCorrection]::new($CorrectionParams)

    if ($OutputAs -eq 'CorrectionExtent') {
        $Correction = $Correction.ToCorrectionExtent()
    }

    return $Correction
}
