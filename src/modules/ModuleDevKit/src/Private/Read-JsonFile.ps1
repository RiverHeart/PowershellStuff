<#
.SYNOPSIS
    Reads and parses a JSON file into a PowerShell object.

.EXAMPLE
    Basic usage

    $json = Read-JsonFile -Path "C:\path\to\file.json" -Description "Sample JSON file"
#>
function Read-JsonFile {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $Description
    )

    if (-not (Test-Path -Path $Path)) {
        throw "$Description was not found: $Path"
    }

    try {
        return (Get-Content -Path $Path -Raw | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        throw "Failed to parse $Description '$Path': $_"
    }
}
