$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path

# Populate Module Scope
#------------------------

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
$ManifestPath = Join-Path -Path $ModuleRoot -ChildPath 'TabCentral.psd1'
if (-not (Test-Path -Path $ManifestPath)) {
    throw "Module manifest not found at '$ManifestPath'."
}
try {
    $Manifest = Import-PowerShellDataFile -Path $ManifestPath -ErrorAction Stop
} catch {
    throw "Failed to load module manifest '$ManifestPath'. Error: $_"
}

$FunctionsToExport = if ($Manifest.ContainsKey('FunctionsToExport')) { $Manifest.FunctionsToExport } else { @() }
$CmdletsToExport = if ($Manifest.ContainsKey('CmdletsToExport')) { $Manifest.CmdletsToExport } else { @() }
$VariablesToExport = if ($Manifest.ContainsKey('VariablesToExport')) { $Manifest.VariablesToExport } else { @() }
$AliasesToExport = if ($Manifest.ContainsKey('AliasesToExport')) { $Manifest.AliasesToExport } else { @() }

Export-ModuleMember `
    -Function $FunctionsToExport `
    -Cmdlet $CmdletsToExport `
    -Variable $VariablesToExport `
    -Alias $AliasesToExport


# Resource Cleanup
#-----------------

<#
NOTE:
    The following block of code will probably be useful at some point so
    I'm leaving this here.

    See: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/remove-module?view=powershell-7.6#example-5-using-the-onremove-event
#>

# # Perform any necessary cleanup when the module is removed
# $OnRemoveScript = {}
# $ExecutionContext.SessionState.Module.OnRemove += $OnRemoveScript
# $RegisterEngineEventParams = @{
#     Action = $OnRemoveScript
#     SourceIdentifier = ([System.Management.Automation.PSEngineEvent]::Exiting)
# }
# Register-EngineEvent @RegisterEngineEventParams
