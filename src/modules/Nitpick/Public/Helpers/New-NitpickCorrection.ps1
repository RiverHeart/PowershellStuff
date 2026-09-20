
<#
.SYNOPSIS
    Creates a new Nitpick correction extent for a given AST node.

.DESCRIPTION
    This function generates a collection of correction extents based on the
    provided AST node, which can be used by the Nitpick module to suggest code corrections.
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
