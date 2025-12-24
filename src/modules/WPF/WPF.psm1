$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path

$script:LastDialogResult = $false
if (-not $Script:WPFControlTable) {
    $Script:WPFControlTable = @{}
}

$Paths = @(
    'Private'
    'Public'
)

foreach ($Path in $Paths) {
    Get-ChildItem "$ModuleRoot/$Path" -Recurse -Filter '*.ps1' |
        ForEach-Object {
            . $_.FullName
        }
}
