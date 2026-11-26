<#
.SYNOPSIS
    Converts a single-suite manifest to a list of test suites.
#>
function Convert-SingleSuiteManifestToSuiteList {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object] $Config,

        [Parameter(Mandatory)]
        [string] $ConfigPath
    )

    Test-SuiteManifest -SuiteConfig $Config -Path $ConfigPath

    $SuiteName = if (
        ($Config.PSObject.Properties.Name -contains 'TestSuite') -and
        -not [string]::IsNullOrWhiteSpace([string] $Config.TestSuite)
    ) {
        [string] $Config.TestSuite
    } else {
        'Default'
    }

    return @(
        [pscustomobject]@{
            Name       = $SuiteName
            ConfigPath = $ConfigPath
        }
    )
}
