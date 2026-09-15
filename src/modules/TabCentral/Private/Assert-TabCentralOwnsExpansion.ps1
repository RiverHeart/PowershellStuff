<#
.SYNOPSIS
    Asserts that a TabExpansion2 script block is owned by TabCentral.

.DESCRIPTION
    Uses both script block identity and script file provenance to determine
    whether a target TabExpansion2 implementation belongs to this TabCentral
    module instance.
#>
function Assert-TabCentralOwnsExpansion {
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [object] $TargetScriptBlock
    )

    if ($TargetScriptBlock -is [System.Management.Automation.FunctionInfo]) {
        $TargetScriptBlock = $TargetScriptBlock.ScriptBlock
    }

    if (-not $TargetScriptBlock) {
        $GlobalTabExpansion = Get-Command -Name 'global:TabExpansion2' -CommandType Function -ErrorAction SilentlyContinue
        if (-not $GlobalTabExpansion) {
            $GlobalTabExpansion = Get-Item -Path Function:\global:TabExpansion2 -ErrorAction SilentlyContinue
        }
        if (-not $GlobalTabExpansion) {
            throw 'Global TabExpansion2 function was not found.'
        }

        if ($GlobalTabExpansion -is [System.Management.Automation.FunctionInfo]) {
            $TargetScriptBlock = $GlobalTabExpansion.ScriptBlock
        } else {
            $TargetScriptBlock = $GlobalTabExpansion
        }
    }

    if ($script:TabCentralTabExpansion2 -and
        [object]::ReferenceEquals($TargetScriptBlock, $script:TabCentralTabExpansion2)
    ) {
        return
    }

    $TargetFile = $null
    if ($TargetScriptBlock.Ast -and $TargetScriptBlock.Ast.Extent) {
        $TargetFile = $TargetScriptBlock.Ast.Extent.File
    }

    $TabCentralTabExpansionPath = Join-Path -Path $PSScriptRoot -ChildPath '..\Public\TabExpansion2.ps1'
    $TabCentralTabExpansionPath = [System.IO.Path]::GetFullPath($TabCentralTabExpansionPath)

    if ($TargetFile) {
        $ResolvedTargetFile = [System.IO.Path]::GetFullPath($TargetFile)
        if ($ResolvedTargetFile -ieq $TabCentralTabExpansionPath) {
            return
        }
    }

    throw 'Current TabExpansion2 is not owned by TabCentral.'
}
