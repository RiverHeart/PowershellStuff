using module AstEditor

<#
.SYNOPSIS
    Guided correction selector: shows a finding in the editor and prompts for a correction.

.DESCRIPTION
    Supplied by the target coordinator as the CorrectionSelector for -FixMode Guided.
    It is invoked only for findings that require a choice. When PowerShell Editor
    Services ($psEditor) is available and the document has source provenance, the
    violation range is selected in the editor before prompting; navigation failures
    are reported as warnings and never block the prompt. Navigation does not make an
    in-memory document eligible for file saves.

    Corrections are listed with their applicability when it is not Safe. A blank or
    end-of-input answer skips the finding.

.PARAMETER Finding
    The finding requiring a decision. Its ViolationExtent uses snapshot coordinates.

.PARAMETER Correction
    The corrections offered for the finding.

.PARAMETER Document
    The AstDocument analyzed for the finding. It remains in-memory for Script input.

.EXAMPLE
    Select-NitpickGuidedCorrection -Finding $Finding -Correction $Finding.Corrections -Document $Document
#>
function Select-NitpickGuidedCorrection {
    [CmdletBinding()]
    [OutputType('NitpickCorrection')]
    param(
        [Parameter(Mandatory)]
        [NitpickFinding] $Finding,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [NitpickCorrection[]] $Correction,

        [Parameter(Mandatory)]
        [AstDocument] $Document
    )

    if ($Correction.Count -eq 0) {
        return
    }

    $Extent = $Finding.ViolationExtent
    $Location = '{0}:{1}' -f $Extent.StartLineNumber, $Extent.StartColumnNumber

    if ($Extent.File) {
        $Location = '{0}:{1}:{2}' -f $Extent.File, $Extent.StartLineNumber, $Extent.StartColumnNumber
        try {
            if ($PSEditor) {
                Write-Verbose "Opening $($Extent.File) in the editor."
                $PSEditor.Workspace.OpenFile($Extent.File)
                $PSEditor.GetEditorContext().SetSelection(
                    $Extent.StartLineNumber,
                    $Extent.StartColumnNumber,
                    $Extent.EndLineNumber,
                    $Extent.EndColumnNumber
                )
            }
        } catch {
            Write-Warning "Could not navigate to $Location in the editor: $($_.Exception.Message)"
        }
    }

    Write-Host ''
    Write-Host ('{0}  {1}  {2}' -f $Location, $Finding.Message, (Get-NitpickRuleLabel -InputObject $Finding))
    Write-Host 'Choose a correction (leave blank to skip this finding):'
    for ($i = 0; $i -lt $Correction.Count; $i++) {
        $Label = if ($Correction[$i].Applicability -ne 'Safe') { "($($Correction[$i].Applicability)) " } else { '' }
        Write-Host "  [$i] $Label$($Correction[$i].Description)"
    }

    while ($true) {
        # Read-Host returns null at end of input, which must not loop forever.
        $Selection = Read-Host 'Enter the number of the correction to apply'
        if ([string]::IsNullOrWhiteSpace($Selection)) {
            return
        }

        $Index = 0
        if ([int]::TryParse($Selection.Trim(), [ref] $Index) -and
            $Index -ge 0 -and
            $Index -lt $Correction.Count
        ) {
            return $Correction[$Index]
        }

        Write-Host 'Invalid selection. Please try again.' -ForegroundColor Red
    }
}
