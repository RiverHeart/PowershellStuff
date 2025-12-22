$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path

$Paths = @(
    'Public'
)

foreach ($Path in $Paths) {
    Get-ChildItem "$ModuleRoot/$Path" -Recurse -Filter '*.ps1' |
        ForEach-Object {
            . $_.FullName
        }
}
