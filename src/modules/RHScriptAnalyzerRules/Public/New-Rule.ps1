<#
.SYNOPSIS
    Creates a new PSScriptAnalyzer rule template.
#>
function New-Rule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [ValidateNotNullOrEmpty()]
        [string] $OutDirectory
    )

    # Doing this because DirectoryInfo is resolving `.` to the workspace
    # directory for some reason.
    if ($OutDirectory -and -not [System.IO.Path]::IsPathRooted($OutDirectory)) {
        $OutDirectory = Join-Path -Path (Get-Location) -ChildPath $OutDirectory
    }
    if (-not $OutDirectory) { $OutDirectory = Get-Location }
    $ResolvedOutDirectory = [System.IO.DirectoryInfo]::new($OutDirectory)  # Resolve to an absolute path
    if (-not $ResolvedOutDirectory.Exists) { $ResolvedOutDirectory.Create() | Out-Null }

    $OutPath = Join-Path -Path $ResolvedOutDirectory.FullName -ChildPath "$Name.ps1"

    if (Test-Path -LiteralPath $OutPath -PathType Leaf) {
        Write-Error "The file '$OutPath' already exists." -Category ResourceExists
        return
    }

    $RuleTemplate = @'
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    PSScriptAnalyzer rule.
#>
function __Name__ {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst] $ScriptBlockAst,

        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
        [string] $FilePath
    )

    process {
        try {
            $MatchingNodes = $ScriptBlockAst.FindAll({
                param($Ast)

                # Implement your matching logic here

                # Matching nothing in case this rule is auto-detected by ScriptAnalyzer
                return $false
            }, $false <# DO NOT RECURSE, you will get duplicate matches from Invoke-ScriptAnalyzer #>)

            $MatchingNodes | ForEach-Object {
                $BadNode = $_

                $FilePath = if ($BadNode.Extent.FileName) {
                    $BadNode.Extent.FileName
                } else {
                    Get-PSCallStack | Where-Object { $_.ScriptName } | Select-Object -Last 1 -ExpandProperty ScriptName
                }
                if (-not $FilePath) { $FilePath = '<ScriptBlock>' }

                #$CorrectionExtent = [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]::new(
                #    $BadNode.Extent.StartLineNumber,
                #    $BadNode.Extent.EndLineNumber,
                #    $BadNode.Extent.StartColumnNumber,
                #    $BadNodeEndColumnNumber,
                #    $ReplacementText,
                #    $FilePath,  # File Path or Context
                #    $Description  # Hover Text Description
                #)
                #$SuggestedCorrections = [System.Collections.ObjectModel.Collection[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]]::new()
                #$SuggestedCorrections.Add($CorrectionExtent)

                $DiagnosticRecord = [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
                    Message = "Placeholder message for __Name__"
                    Extent = $BadNode.Extent
                    RuleName = $PSCmdlet.MyInvocation.MyCommand.Name
                    Severity = 'Information'
                    RuleSuppressionID = 'PSAvoidParameterAttributeBool'
                    #SuggestedCorrections = $SuggestedCorrections
                }

                Write-Output $DiagnosticRecord
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
'@ -replace '__Name__', $Name

    $RuleTemplate | Out-File -FilePath $OutPath -Force
}
