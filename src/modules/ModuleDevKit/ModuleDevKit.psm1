$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path
$ModuleName = $ModuleRoot | Split-Path -Leaf

$Paths = @(
    'src/Classes'
    'src/Private'
    'src/Public'
)

foreach ($Path in $Paths) {
    Get-ChildItem (Join-Path $ModuleRoot $Path) -Recurse -Filter '*.ps1' |
        ForEach-Object {
            . $_.FullName
        }
}

$ManifestPath = Join-Path -Path $ModuleRoot -ChildPath "$ModuleName.psd1"
if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "Module manifest not found at '$ManifestPath'."
}

try {
    $Manifest = Import-PowerShellDataFile -LiteralPath $ManifestPath -ErrorAction Stop
} catch {
    throw "Failed to load module manifest '$ManifestPath'. Error: $_"
}

Export-ModuleMember `
    -Function $Manifest.FunctionsToExport `
    -Cmdlet $Manifest.CmdletsToExport `
    -Variable $Manifest.VariablesToExport `
    -Alias $Manifest.AliasesToExport
