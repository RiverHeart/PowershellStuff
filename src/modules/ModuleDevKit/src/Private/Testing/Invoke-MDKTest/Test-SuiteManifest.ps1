<#
.SYNOPSIS
    Validates the structure of a test suite manifest.

.DESCRIPTION
    This function checks that the provided test suite manifest object
    contains the required 'Run' section and that the 'Run' section
    includes at least one 'Path' entry.

.EXAMPLE
    Basic usage

    Test-SuiteManifest -SuiteConfig $suiteConfig -Path "C:\path\to\manifest.json"
#>
function Test-SuiteManifest {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [object] $SuiteConfig,

        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not ($SuiteConfig.PSObject.Properties.Name -contains 'Run') -or
        $null -eq $SuiteConfig.Run) {
        throw "Suite config '$Path' must define Run."
    }

    if (-not ($SuiteConfig.Run.PSObject.Properties.Name -contains 'Path')) {
        throw "Suite config '$Path' must define Run.Path."
    }

    if ($SuiteConfig.Run.Path.Count -eq 0) {
        throw "Suite config '$Path' must include at least one Run.Path entry."
    }
}
