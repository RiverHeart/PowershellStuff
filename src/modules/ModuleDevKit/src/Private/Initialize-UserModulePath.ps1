<#
.SYNOPSIS
    Initializes the user module path for the current PowerShell session.

.DESCRIPTION
    This function ensures that the user-specific module path is included in the PSModulePath
    environment variable for the current PowerShell session. It handles different operating
    systems and PowerShell editions appropriately.

.EXAMPLE
    Basic usage

    Initialize-UserModulePath
#>
function Initialize-UserModulePath {
    [CmdletBinding()]
    param()

    $UserModulePath = if ($IsLinux -or $IsMacOS) {
        Join-Path $HOME '.local/share/powershell/Modules'
    } else {
        $UserModuleDirectoryName = if ($PSEdition -eq 'Desktop') {
            'WindowsPowerShell'
        } else {
            'PowerShell'
        }
        $DocumentsPath = [Environment]::GetFolderPath('MyDocuments')
        Join-Path $DocumentsPath "$UserModuleDirectoryName\Modules"
    }
    $ModulePaths = @($env:PSModulePath -split [IO.Path]::PathSeparator)

    if ((Test-Path -LiteralPath $UserModulePath) -and $UserModulePath -notin $ModulePaths) {
        $env:PSModulePath = $UserModulePath + [IO.Path]::PathSeparator + $env:PSModulePath
        Write-Debug "Added the $PSEdition user module path to PSModulePath: $UserModulePath"
    }
}
