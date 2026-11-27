<#
.SYNOPSIS
    Validates a collection of named test suites.

.DESCRIPTION
    Ensures each suite has a unique name and either an inline Run configuration
    or a path to a separate suite configuration.

.PARAMETER TestSuites
    Test suite entries to validate.

.PARAMETER Path
    Config file path used in validation errors.

.NOTES
    Examples for this private helper run in the module's scope.
#>
function Test-MDKTestSuiteCollection {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $TestSuites,

        [Parameter(Mandatory)]
        [string] $Path
    )

    if ($TestSuites.Count -eq 0) {
        throw "Config '$Path' must define at least one test suite."
    }

    $Names = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($Suite in $TestSuites) {
        if (-not ($Suite.PSObject.Properties.Name -contains 'Name') -or
            [string]::IsNullOrWhiteSpace([string] $Suite.Name)
        ) {
            throw "Each test suite in '$Path' must define a non-empty Name."
        }

        if (-not $Names.Add([string] $Suite.Name)) {
            throw "Test suite '$($Suite.Name)' is defined more than once in '$Path'."
        }

        $hasConfigPath = (
            ($Suite.PSObject.Properties.Name -contains 'ConfigPath') -and
            -not [string]::IsNullOrWhiteSpace([string] $Suite.ConfigPath)
        )

        $hasInlineSuiteConfig = (
            ($Suite.PSObject.Properties.Name -contains 'Run') -and
            $null -ne $Suite.Run
        )

        if ($hasConfigPath -eq $hasInlineSuiteConfig) {
            throw "Test suite '$($Suite.Name)' in '$Path' must define either ConfigPath or inline Run configuration, but not both."
        }

        if ($hasInlineSuiteConfig) {
            Test-SuiteManifest -SuiteConfig $Suite -Path "$Path (test suite '$($Suite.Name)')"
        }
    }
}
