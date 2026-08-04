$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path

$Folders = @(
    'Classes'
    'Private'
    'Public'
)

foreach ($Path in $Folders) {
    Get-ChildItem -LiteralPath (Join-Path $ModuleRoot $Path) -Filter '*.ps1' |
        ForEach-Object {
            . $_.FullName
        }
}

$Manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $ModuleRoot 'AstEditor.psd1')
Export-ModuleMember `
    -Function $Manifest.FunctionsToExport `
    -Cmdlet $Manifest.CmdletsToExport `
    -Variable $Manifest.VariablesToExport `
    -Alias $Manifest.AliasesToExport
































