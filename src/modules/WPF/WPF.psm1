$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path

# NOTE: I should probably separate classes from functions and load them first to avoid
# issues. I could also require classes to be named like `*.class.ps1` to make it
# easier to identify and load them first.

# Populate Module Scope
#------------------------

$script:LastDialogResult = $false
$script:LastDialogCloseReason = 'Unknown'

# Create module var to map context ids to control tables
if (-not $Script:WPFControlRegistry) {
    $Script:WPFControlRegistry = [ordered] @{
        ActiveContextId = $null
        Contexts        = @{}
    }
}

if (-not $Script:WPFThemeTable) {
    $Script:WPFThemeTable = @{}
}

if (-not $Script:WPFStyleTable) {
    $Script:WPFStyleTable = @{}
}

if (-not $Script:WPFImplicitStyleTable) {
    $Script:WPFImplicitStyleTable = @{}
}

if (-not $Script:WPFThemeState) {
    $Script:WPFThemeState = [ordered]@{
        ActiveTheme = $null
    }
}

# Load FileInfo objects
if (-not $Script:WPFFileInfo) {
    $Script:WPFFileInfo = Import-PowerShellDataFile -Path "$ModuleRoot/Private/Data/FileInfo.psd1"
}

$Paths = @(
    'Private'
    'Public'
    'TypeConverters'
)

foreach ($Path in $Paths) {
    Get-ChildItem "$ModuleRoot/$Path" -Recurse -Filter '*.ps1' |
        ForEach-Object {
            . $_.FullName
        }
}

# Export Resources
#-----------------

# `psm1` exports everything by default instead of respecting the `psd1` manifest,
# as you'd expect, unless `Export-ModuleMember` is used to explicitly specify exports.
# As a workaround, load the manifest and use that to determine what to export.
# Fortunately, aliases defined by attribute decorators are still exported by default.
$ManifestPath = Join-Path -Path $ModuleRoot -ChildPath 'WPF.psd1'
$Manifest = Import-PowerShellDataFile -Path $ManifestPath

$FunctionsToExport = if ($Manifest.ContainsKey('FunctionsToExport')) { $Manifest.FunctionsToExport } else { @() }
$CmdletsToExport = if ($Manifest.ContainsKey('CmdletsToExport')) { $Manifest.CmdletsToExport } else { @() }
$VariablesToExport = if ($Manifest.ContainsKey('VariablesToExport')) { $Manifest.VariablesToExport } else { @() }
$AliasesToExport = if ($Manifest.ContainsKey('AliasesToExport')) { $Manifest.AliasesToExport } else { @() }

Export-ModuleMember `
    -Function $FunctionsToExport `
    -Cmdlet $CmdletsToExport `
    -Variable $VariablesToExport `
    -Alias $AliasesToExport
