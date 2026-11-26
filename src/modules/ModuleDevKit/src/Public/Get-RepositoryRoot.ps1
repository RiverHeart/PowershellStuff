<#
.SYNOPSIS
    Gets the root directory of a Git repository or a project with a
    'pester.json' marked as root.

.DESCRIPTION
    The Get-RepositoryRoot function searches for the root of a repository
    starting from a specified path.

    It checks for the presence of a '.git' directory or a 'pester.json' file
    with 'isRoot' set to true.

.PARAMETER StartDirectories
    One or more paths from which to search upward.

.EXAMPLE
    Returns the root directory of the Git repository or the project with a
    'pester.json' marked as root, starting from the specified path.

    Get-RepositoryRoot -StartPath 'C:\Projects\MyRepo'
#>
function Get-RepositoryRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [Alias('StartPath')]
        [string[]] $StartDirectories
    )

    foreach ($startDirectory in $StartDirectories) {
        if (-not [string]::IsNullOrWhiteSpace($startDirectory)) {
            $candidate = Resolve-Path -Path $startDirectory -ErrorAction SilentlyContinue
            if ($null -eq $candidate) {
                continue
            }

            $current = $candidate.Path
            while ($current -ne [System.IO.Path]::GetPathRoot($current)) {
                $RootConfigPath = Join-Path $current 'pester.json'
                if (Test-Path -Path $RootConfigPath) {
                    try {
                        $RootConfig = Get-Content -Path $RootConfigPath -Raw |
                            ConvertFrom-Json -ErrorAction Stop
                        if (
                            $RootConfig.PSObject.Properties.Name -contains 'isRoot' -and
                            [bool] $RootConfig.isRoot
                        ) {
                            return $current
                        }
                    } catch {
                        Write-Debug "Ignoring invalid root config at '$RootConfigPath': $_"
                    }
                }

                if (Test-Path -Path (Join-Path $current '.git')) {
                    return $current
                }

                $parent = Split-Path -Path $current -Parent
                if ($parent -eq $current) {
                    break
                }

                $current = $parent
            }
        }
    }

    return $null
}
