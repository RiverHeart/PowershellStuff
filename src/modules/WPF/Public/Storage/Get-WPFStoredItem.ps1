<#
.SYNOPSIS
    Reads an item from WPF application storage.

.DESCRIPTION
    Deserializes an item from the supplied application storage context. JSON is
    used by default. A missing item returns no output.
#>
function Get-WPFStoredItem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Storage,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [ValidateSet('CliXml', 'Json')]
        [string] $Format = 'Json'
    )

    $ItemPath = Resolve-WPFStorageItemPath -Storage $Storage -Name $Name -Format $Format
    if (-not (Test-Path -LiteralPath $ItemPath -PathType Leaf)) {
        return
    }

    switch ($Format) {
        'CliXml' {
            Import-Clixml -LiteralPath $ItemPath -ErrorAction Stop
        }
        'Json' {
            [System.IO.File]::ReadAllText($ItemPath) | ConvertFrom-Json -ErrorAction Stop
        }
    }
}
