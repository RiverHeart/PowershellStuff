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
        [System.IO.DirectoryInfo] $OutDirectory
    )

    if (-not $OutDirectory) { $OutDirectory = (Get-Location).ToString() }
    if (-not $OutDirectory.Exists) { $OutDirectory.Create() | Out-Null }

    $OutPath = Join-Path -Path $OutDirectory.FullName -ChildPath "$Name.ps1"

    if (Test-Path -LiteralPath $OutPath -PathType Leaf) {
        Write-Error "The file '$OutPath' already exists."
        return
    }

    $RuleTemplate = @'
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    PSScriptAnalyzer rule.
#>
function {0} {
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
            $FindAstNodeParams = @{
                Type = ''  # Change me
                Recurse = $true
            }

            Find-Ast @FindAstNodeParams

            if ($PSBoundParameters.ContainsKey('FilePath')) {
                $FindAstNodeParams.FilePath = $FilePath
            } elseif ($PSBoundParameters.ContainsKey('ScriptBlockAst')) {
                $FindAstNodeParams.Ast = $ScriptBlockAst
            } else {
                Write-Error 'Either ScriptBlockAst or FilePath is required.'
                return
            }

            Find-AstNode @FindAstNodeParams | ForEach-Object {
                [PSCustomObject]@{
                    Message = ""  # Change me
                    Extent = $_.Extent
                    RuleName = $PSCmdlet.MyInvocation.MyCommand.Name
                    Severity = 'Warning'
                    RuleSuppressionId = ''  # Change me
                }
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
'@ -f $Name

    $RuleTemplate | Out-File -FilePath $OutPath -Force
}
