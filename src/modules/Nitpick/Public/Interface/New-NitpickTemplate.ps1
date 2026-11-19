<#
.SYNOPSIS
    Creates a new Nitpick rule template.
#>
function New-NitpickTemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory,ParameterSetName='Default')]
        [ValidateSet('Style', 'Quality', 'Security', 'Performance', 'Maintainability', 'Other')]
        [string] $Category,

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

    $OutPath = Join-Path -Path $ResolvedOutDirectory.FullName -ChildPath "$Name.Rule.ps1"

    if (Test-Path -LiteralPath $OutPath -PathType Leaf) {
        Write-Error "The file '$OutPath' already exists." -Category ResourceExists
        return
    }

    $RuleTemplate = @'
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Nitpick rule.

.EXAMPLE
    Basic usage

    __Name__ -ScriptBlockAst {
        # Code to analyze goes here
    }.Ast
#>
function __Name__ {
    [CmdletBinding(DefaultParameterSetName='ScriptBlockAst')]
    [OutputType('NitpickFinding', 'PSCustomObject')]
    param(
        [Parameter(Mandatory,ParameterSetName='ScriptBlockAst')]
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst] $ScriptBlockAst,

        [Parameter(ParameterSetName='ScriptBlockAst')]
        [System.Collections.IDictionary] $Context,

        [Parameter(Mandatory,ParameterSetName='Details')]
        [switch] $Details
    )

    process {
        try {
            $Command = $PSCmdlet.MyInvocation.MyCommand
            $RuleName = $Command.Noun
            $Metadata = [pscustomobject]@{
                Name = $RuleName
                CommandName = $Command.Name
                Category = '__Category__'
                Description = 'Describe the rule.'
                Severity = 'Information'
                Explanation = 'Explain why the rule reports a finding.'
            }
            if ($Details) {
                Write-Output $Metadata
                return
            }

            $ShouldRecurse = $Context.RuleBehavior.SearchNestedScriptBlocks -eq $true
            $MatchingNodes = $ScriptBlockAst.FindAll({
                param($Ast)

                # Implement your matching logic here

                return $false
            }, $ShouldRecurse)

            $MatchingNodes | ForEach-Object {
                $BadNode = $_

                $ScriptPath = if ($BadNode.Extent.File) {
                    $BadNode.Extent.File
                } else {
                    '<ScriptBlock>'
                }

                New-NitpickFinding `
                    -RuleId "Nitpick/$RuleName" `
                    -Message 'Describe the finding.' `
                    -ViolationExtent $BadNode.Extent `
                    -Severity $Metadata.Severity `
                    -ScriptPath $ScriptPath `
                    -Explanation $Metadata.Explanation `
                    -Corrections @()
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
'@ -replace '__Name__', $Name -replace '__Category__', $Category

    $RuleTemplate | Out-File -FilePath $OutPath -Force
}
