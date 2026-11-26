using namespace System.IO
using namespace System.Collections.Generic

function Resolve-CoverageOutputPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object] $SuiteConfig,

        [Parameter(Mandatory)]
        [string] $RepositoryRoot,

        [Parameter(Mandatory)]
        [string] $TestSuite
    )

    if ($null -ne $SuiteConfig.Coverage -and
        $SuiteConfig.Coverage.PSObject.Properties.Name -contains 'OutputPath' -and
        -not [string]::IsNullOrWhiteSpace([string] $SuiteConfig.Coverage.OutputPath)
    ) {
        $configuredOutputPath = [string] $SuiteConfig.Coverage.OutputPath
        if ([Path]::IsPathRooted($configuredOutputPath)) {
            return $configuredOutputPath
        }

        return (Join-Path -Path $RepositoryRoot -ChildPath $configuredOutputPath)
    }

    return (Join-Path -Path $RepositoryRoot -ChildPath ("artifacts/coverage/{0}.coverage.xml" -f $TestSuite))
}
