using namespace System.Collections
using namespace System.Management.Automation

<#
.SYNOPSIS
    Evaluates a rule predicate, requiring exactly one Boolean success-stream value.

.DESCRIPTION
    Promotes predicate errors to terminating NitpickApplicabilityFailed records.
    Missing, multiple, or non-Boolean output terminates with
    NitpickInvalidApplicabilityResult, never a truthiness-based decision.

.EXAMPLE
    Test Nitpick rule applicability with a context that has no policy.
    Returns False because this context declares no policy.

    Test-NitpickRuleApplicability `
        -RuleId 'Local/ProjectRule' `
        -Context @{ Policy = @{} } `
        -Applicability {
            param([System.Collections.IDictionary] $Context)
            $Context.Policy.Count -gt 0
        }

.NOTES
    Private helper. The dispatcher supplies an isolated context copy.
#>
function Test-NitpickRuleApplicability {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $Applicability,

        [Parameter(Mandatory)]
        [IDictionary] $Context,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $RuleId
    )

    try {
        $ErrorActionPreference = 'Stop'
        $Values = @(& $Applicability $Context 2>&1)

        foreach ($Value in $Values) {
            if ($Value -is [ErrorRecord]) {
                throw $Value
            }
        }
    } catch {
        $Exception = [InvalidOperationException]::new(
            "Applicability for rule '$RuleId' failed: $($_.Exception.Message)", $_.Exception
        )

        $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new(
            $Exception,
            'NitpickApplicabilityFailed',
            [ErrorCategory]::InvalidOperation,
            $RuleId
        ))
    }

    if ($Values.Count -ne 1 -or $Values[0] -isnot [bool]) {
        $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new(
            [InvalidOperationException]::new("Applicability for rule '$RuleId' must return exactly one Boolean."),
            'NitpickInvalidApplicabilityResult', [ErrorCategory]::InvalidResult, $RuleId
        ))
    }

    return $Values[0]
}
