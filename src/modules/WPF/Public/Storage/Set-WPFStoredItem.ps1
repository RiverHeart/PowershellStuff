<#
.SYNOPSIS
    Writes an item to WPF application storage.

.DESCRIPTION
    Serializes a value to a temporary file and atomically replaces the stored
    item. JSON is used by default. Concurrent writes to the same item are
    rejected.
#>
function Set-WPFStoredItem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Storage,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Value,

        [ValidateSet('CliXml', 'Json')]
        [string] $Format = 'Json',

        [ValidateRange(1, 100)]
        [int] $Depth = 10
    )

    $ItemPath = Resolve-WPFStorageItemPath `
        -Storage $Storage `
        -Name $Name `
        -Format $Format `
        -ErrorAction Stop
    $LockPath = "$ItemPath.lock"
    $TemporaryPath = "$ItemPath.$([guid]::NewGuid().ToString('N')).tmp"
    $BackupPath = "$ItemPath.$([guid]::NewGuid().ToString('N')).bak"
    $LockStream = $null

    try {
        try {
            $LockStream = [System.IO.File]::Open(
                $LockPath,
                [System.IO.FileMode]::OpenOrCreate,
                [System.IO.FileAccess]::ReadWrite,
                [System.IO.FileShare]::None
            )
        } catch [System.IO.IOException] {
            Write-Error "Storage item '$Name' is currently being written by another process." -Category ResourceBusy
            return
        }

        switch ($Format) {
            'CliXml' {
                Export-Clixml -InputObject $Value -LiteralPath $TemporaryPath -ErrorAction Stop
            }
            'Json' {
                $Json = ConvertTo-Json -InputObject $Value -Depth $Depth -ErrorAction Stop
                [System.IO.File]::WriteAllText($TemporaryPath, $Json)
            }
        }

        if (Test-Path -LiteralPath $ItemPath -PathType Leaf) {
            [System.IO.File]::Replace($TemporaryPath, $ItemPath, $BackupPath)
        } else {
            [System.IO.File]::Move($TemporaryPath, $ItemPath)
        }
    } finally {
        if ($null -ne $LockStream) {
            $LockStream.Dispose()
        }
        if (Test-Path -LiteralPath $TemporaryPath) {
            Remove-Item -LiteralPath $TemporaryPath -Force
        }
        if (Test-Path -LiteralPath $BackupPath) {
            Remove-Item -LiteralPath $BackupPath -Force
        }
    }
}
