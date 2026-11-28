<#
.SYNOPSIS
    Finds Git ignore files that can apply to a project.

.PARAMETER ProjectRoot
    Root directory of the project being packaged.

.EXAMPLE
    Get-GitIgnoreFile -ProjectRoot $PWD
#>
function Get-GitIgnoreFile {
    [OutputType([System.IO.FileInfo])]
    param (
        [Parameter(Mandatory)]
        [string] $ProjectRoot
    )

    $CommonParams = @{
        Filter = '.gitignore'
        File = $true
        Force = $true
    }

    Get-ChildItem `
        @CommonParams `
        -LiteralPath $ProjectRoot `
        -Recurse `
        -ErrorAction Stop

    $Parent = Split-Path -Path $ProjectRoot -Parent
    while ($Parent) {
        Get-ChildItem `
            @CommonParams `
            -LiteralPath $Parent `
            -ErrorAction SilentlyContinue

        $Parent = Split-Path -Path $Parent -Parent
    }
}
