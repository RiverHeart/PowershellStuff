function Test-RootManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $RootConfig,

        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not ($RootConfig.PSObject.Properties.Name -contains 'isRoot') -or
        -not [bool] $RootConfig.isRoot
    ) {
        throw "Root config '$Path' must contain isRoot=true."
    }

    if (-not ($RootConfig.PSObject.Properties.Name -contains 'TestSuites')) {
        throw "Root config '$Path' is missing TestSuites."
    }

    $Suites = @($RootConfig.TestSuites)
    if ($Suites.Count -eq 0) {
        throw "Root config '$Path' must define at least one suite in TestSuites."
    }

    foreach ($Suite in $Suites) {
        if (-not ($Suite.PSObject.Properties.Name -contains 'Name') -or
            [string]::IsNullOrWhiteSpace([string] $Suite.Name)
        ) {
            throw "Each suite in '$Path' must define a non-empty Name."
        }

        $hasConfigPath = (
            ($Suite.PSObject.Properties.Name -contains 'ConfigPath') -and
            -not [string]::IsNullOrWhiteSpace([string] $Suite.ConfigPath)
        )

        $hasInlineSuiteConfig = (
            ($Suite.PSObject.Properties.Name -contains 'Run') -and
            $null -ne $Suite.Run
        )

        if ($hasConfigPath -and $hasInlineSuiteConfig) {
            throw "Suite '$($Suite.Name)' in '$Path' cannot define both ConfigPath and inline Run configuration. Choose one style per suite."
        }

        if (-not $hasConfigPath -and -not $hasInlineSuiteConfig) {
            throw "Suite '$($Suite.Name)' in '$Path' must define either ConfigPath or an inline suite Run configuration."
        }

        if ($hasInlineSuiteConfig) {
            Test-SuiteManifest -SuiteConfig $Suite -Path "$Path (suite '$($Suite.Name)')"
        }
    }
}
