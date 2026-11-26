function Resolve-EffectiveCoverageMode {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $RequestedMode,

        [Parameter(Mandatory)]
        [object] $SuiteConfig
    )

    if ($RequestedMode -ne 'FromConfig') {
        return $RequestedMode
    }

    if ($SuiteConfig.PSObject.Properties.Name -contains 'Coverage' -and
        $null -ne $SuiteConfig.Coverage -and
        ($SuiteConfig.Coverage.PSObject.Properties.Name -contains 'Mode') -and
        -not [string]::IsNullOrWhiteSpace([string] $SuiteConfig.Coverage.Mode)
    ) {
        $configMode = [string] $SuiteConfig.Coverage.Mode
        switch -Regex ($configMode) {
            '^(?i)full$' { return 'Full' }
            '^(?i)new[-_]?code[-_]?analysis$' { return 'NewCodeAnalysis' }
            default {
                throw "Unsupported Coverage.Mode '$configMode'. Use Full or NewCodeAnalysis."
            }
        }
    }

    return 'Full'
}
