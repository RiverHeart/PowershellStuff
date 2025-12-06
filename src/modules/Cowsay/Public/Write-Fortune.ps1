<#
.SYNOPSIS
    Returns a randomly selected quote.

.DESCRIPTION
    Returns a randomly selected quote.

    Inspired by the Unix program Fortune, written by Ken Arnold.

    Given a ### delimited file, get strings, sort randomly and return one.
    To run without specifying a filepath, your $profile should contain

    $env:fortune = "/path/to/fortune/file"

    Probably not the most performant thing in the world, especially on
    large files, but better than nothing.

.EXAMPLE
    fortune "fortunes.txt" | cowsay
#>
function Write-Fortune() {
    [CmdletBinding()]
    [Alias('fortune')]
    [OutputType([string])]
    param(
        [string] $Path = $env:fortune
    )

    if ([String]::IsNullOrEmpty($Path)) {
        $Path = "$PSScriptRoot/../quotes.txt"
    }

    if (-not (Test-Path $Path)) {
        Write-Error "Path not found: '$Path'"
        return ""
    }

    $Fortune =
        Get-Content $Path -Delimiter "%" |
        Sort-Object { Get-Random } |
        Select-Object -First 1 |
        ForEach-Object {
            $_.TrimEnd("%").Trim()
        }

    return $Fortune
}