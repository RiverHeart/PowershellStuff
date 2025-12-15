$moduleRoot = Split-Path -Path $MyInvocation.MyCommand.Path

$paths = @(
    "Public"
)

foreach ($path in $paths) {
    Get-ChildItem "${moduleRoot}\${path}" -Recurse -Filter '*.ps1' |
        ForEach-Object {
            . $_.FullName
        }
}
