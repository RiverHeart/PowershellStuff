$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path

# Capture the currently active TabExpansion2 function (if any) so TabCentral can
# safely fall back without depending on global function copying.
$CommandParams = @{
    Name = 'TabExpansion2'
    CommandType = 'Function'
    ErrorAction = 'SilentlyContinue'
}
if (Get-Command @CommandParams) {
    $script:OriginalTabExpansion2 = (Get-Command @CommandParams).ScriptBlock
}

Update-TypeData `
    -TypeName 'TabCentral.Hook' `
    -DefaultDisplayPropertySet Name, Type, Source, Callable `
    -Force

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

$ModuleTabExpansion = Get-Command -Name 'TabExpansion2' -CommandType Function -ErrorAction SilentlyContinue
if ($ModuleTabExpansion) {
    $script:TabCentralTabExpansion2 = $ModuleTabExpansion.ScriptBlock
}

# If import occurred while a previous TabCentral TabExpansion2 was still global,
# do not treat that implementation as the original fallback.
if ($script:OriginalTabExpansion2) {
    try {
        Assert-TabCentralOwnsExpansion -TargetScriptBlock $script:OriginalTabExpansion2
        $script:OriginalTabExpansion2 = $null
    } catch {
    }
}

# Respect a caller-defined preference from profile; otherwise default to disabled.
if (-not (Get-Variable -Name 'TabCentralEnabled' -Scope Global -ErrorAction SilentlyContinue)) {
    $global:TabCentralEnabled = $false
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

$FunctionsToExport = if ($Manifest.ContainsKey('FunctionsToExport') -and $null -ne $Manifest.FunctionsToExport) { @($Manifest.FunctionsToExport) } else { @() }
$CmdletsToExport = if ($Manifest.ContainsKey('CmdletsToExport') -and $null -ne $Manifest.CmdletsToExport) { @($Manifest.CmdletsToExport) } else { @() }
$VariablesToExport = if ($Manifest.ContainsKey('VariablesToExport') -and $null -ne $Manifest.VariablesToExport) { @($Manifest.VariablesToExport) } else { @() }
$AliasesToExport = if ($Manifest.ContainsKey('AliasesToExport') -and $null -ne $Manifest.AliasesToExport) { @($Manifest.AliasesToExport) } else { @() }

$ExportParams = @{}
if ($FunctionsToExport.Count -gt 0) {
    $ExportParams.Function = $FunctionsToExport
}
if ($CmdletsToExport.Count -gt 0) {
    $ExportParams.Cmdlet = $CmdletsToExport
}
if ($VariablesToExport.Count -gt 0) {
    $ExportParams.Variable = $VariablesToExport
}
if ($AliasesToExport.Count -gt 0) {
    $ExportParams.Alias = $AliasesToExport
}

Export-ModuleMember @ExportParams


# Restore the original global TabExpansion2 when the module unloads, but only
# if the current global function is owned by this TabCentral instance.
$OnRemoveScript = {
    try {
        Assert-TabCentralOwnsExpansion

        if ($script:OriginalTabExpansion2 -and
            $script:TabCentralTabExpansion2 -and
            -not [object]::ReferenceEquals($script:OriginalTabExpansion2, $script:TabCentralTabExpansion2)
        ) {
            Set-Item -Path Function:\global:TabExpansion2 -Value $script:OriginalTabExpansion2 -Force -ErrorAction Stop
        }
    } catch {
    }
}
$ExecutionContext.SessionState.Module.OnRemove += $OnRemoveScript


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
