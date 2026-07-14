<#
.SYNOPSIS
    Installs the TabCentral module to the appropriate PowerShell modules directory.

.DESCRIPTION
    Copies the TabCentral module files from the script's location to the user's
    PowerShell modules directory, creating the directory if it does not exist.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [System.IO.FileInfo] $ModulePath
)

Set-Location -Path $PSScriptRoot

$ModulePath = if ($PSEdition -eq 'Core') {
    "$HOME\Documents\PowerShell\Modules\TabCentral"
} else {
    "$HOME\Documents\WindowsPowerShell\Modules\TabCentral"
}
if (-not (Test-Path -Path $ModulePath)) {
    New-Item -Path $ModulePath -ItemType Directory -Force | Out-Null
}
Copy-Item -Path "$PSScriptRoot/*" -Destination $ModulePath -Recurse -Force
