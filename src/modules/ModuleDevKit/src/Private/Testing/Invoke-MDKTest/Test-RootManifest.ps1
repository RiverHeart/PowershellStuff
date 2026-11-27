<#
.SYNOPSIS
    Validates a root Pester configuration layout.

.DESCRIPTION
    Requires a root marker and exactly one of Projects, TestSuites, or Run,
    then validates the selected layout.

.PARAMETER RootConfig
    Parsed root Pester configuration.

.PARAMETER Path
    Config file path used in validation errors.

.NOTES
    Examples for this private helper run in the module's scope.
#>
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

    $Layouts = @(
        'Projects'
        'TestSuites'
        'Run'
    ) | Where-Object { $RootConfig.PSObject.Properties.Name -contains $_ }

    if ($Layouts.Count -ne 1) {
        throw "Root config '$Path' must define exactly one of Projects, TestSuites, or Run."
    }

    switch ($Layouts[0]) {
        'Projects' {
            $Projects = @($RootConfig.Projects)
            if ($Projects.Count -eq 0) {
                throw "Root config '$Path' must define at least one project in Projects."
            }

            $ProjectNames = [System.Collections.Generic.HashSet[string]]::new(
                [System.StringComparer]::OrdinalIgnoreCase
            )

            foreach ($Project in $Projects) {
                if (-not ($Project.PSObject.Properties.Name -contains 'Name') -or
                    [string]::IsNullOrWhiteSpace([string] $Project.Name)
                ) {
                    throw "Each project in '$Path' must define a non-empty Name."
                }

                if (-not $ProjectNames.Add([string] $Project.Name)) {
                    throw "Project '$($Project.Name)' is defined more than once in '$Path'."
                }

                if (-not ($Project.PSObject.Properties.Name -contains 'ConfigPath') -or
                    [string]::IsNullOrWhiteSpace([string] $Project.ConfigPath)
                ) {
                    throw "Project '$($Project.Name)' in '$Path' must define ConfigPath."
                }
            }
        }
        'TestSuites' {
            Test-MDKTestSuiteCollection -TestSuites @($RootConfig.TestSuites) -Path $Path
        }
        'Run' {
            Test-SuiteManifest -SuiteConfig $RootConfig -Path $Path
        }
    }
}
