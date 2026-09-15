$moduleRoot = Split-Path -Path $MyInvocation.MyCommand.Path

$paths = @(
    "src/Functions"
)

foreach ($path in $paths) {
    Get-ChildItem -Path (Join-Path $moduleRoot $path) -Recurse -File -Filter '*.ps1' |
        Sort-Object -Property FullName |
        ForEach-Object {
            . $_.FullName
        }
}
