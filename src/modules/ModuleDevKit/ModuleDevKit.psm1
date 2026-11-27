$Script:ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path
$Script:ModuleName = $ModuleRoot | Split-Path -Leaf


# MARK: EXPORT
#---------------

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

$ExportParams = @{}
if ($Manifest.FunctionsToExport.Count -gt 0) {
    $ExportParams.Function = $Manifest.FunctionsToExport
}
if ($Manifest.CmdletsToExport.Count -gt 0) {
    $ExportParams.Cmdlet = $Manifest.CmdletsToExport
}
if ($Manifest.VariablesToExport.Count -gt 0) {
    $ExportParams.Variable = $Manifest.VariablesToExport
}
if ($Manifest.AliasesToExport.Count -gt 0) {
    $ExportParams.Alias = $Manifest.AliasesToExport
}

Export-ModuleMember @ExportParams


# MARK: CLEANUP
#----------------

# See: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/remove-module?view=powershell-7.6#example-5-using-the-onremove-event

# Perform any necessary cleanup when the module is removed
<#
$OnRemoveScript = {}
$ExecutionContext.SessionState.Module.OnRemove += $OnRemoveScript
$RegisterEngineEventParams = @{
    Action = $OnRemoveScript
    SourceIdentifier = ([System.Management.Automation.PSEngineEvent]::Exiting)
}
Register-EngineEvent @RegisterEngineEventParams
#>
