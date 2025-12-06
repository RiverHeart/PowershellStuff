$moduleRoot = Split-Path -Path $MyInvocation.MyCommand.Path

$paths = @(
    "Public"
)

foreach ($path in $paths) {
    "${moduleRoot}\${path}\*.ps1" |
        Resolve-Path |
            ForEach-Object {
	            . $_.ProviderPath
            }
}