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

# The behavior of Powershell script module importing seems to be:
#
# 1) The `psm1` exports everything by default unless `Export-ModuleMember` is used to
# explicitly specify exports. On the surface, it does not appear to respect the `psd1`
# manifest as verbose output shows clearly that it exports everything.
#
# 2) However, it also appears to be true that if `psd1` specifies exports, then everything
# not explicitly listed is pruned from the `psm1` exports. This is has to be some dumb legacy
# behavior but what it boils down to is that if you want verbose output to accurately reflect
# what is being exported from the module, then you have to load the manifest in the script
# module and use that to drive `Export-ModuleMember`.
#
# So is this necessary? No, but it bothers me that Powershell is being misleading about what is
# being exported. As a seasoned Powershell user this is confusing and I'm sure that AI agents
# will also struggle with this. So for the sake of clarity and to avoid confusion, I'm going
# to do it this way until it becomes an issue, even if it is redundant.
#
# Fortunately, aliases defined by attribute decorators are still exported by default so those
# don't need to be explicitly listed in the manifest.
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
