<#
.SYNOPSIS
    Joins multiple path segments into a single path using the correct directory separator.

.DESCRIPTION
    This function takes multiple path segments as input and combines them into a
    single path string, ensuring the correct directory separator is used for the
    current operating system.

.NOTES
    This is a PSv5 compatibility function.

    On PSv5, `Join-Path` only supports joining two path segments at a time and
    `[IO.Path]::Combine` doesn't normalize directory separators consistently
    across different platforms.

.EXAMPLE
    Join paths into a single string: 'C:\Folder\SubFolder\File.txt'. Thanks
    to `ValueFromRemainingArguments` commas are optional.

    Join-PathSegments 'C:\Folder' 'SubFolder' 'File.txt'
    Join-PathSegments 'C:\Folder', 'SubFolder', 'File.txt'
#>
function Join-PathSegments {
    param(
        [Parameter(Mandatory,ValueFromRemainingArguments)]
        [string[]] $Paths
    )

    $Separator = [IO.Path]::DirectorySeparatorChar
    return ($Paths | ForEach-Object { $_ -replace '[\\/]', $Separator }) -join $Separator
}
