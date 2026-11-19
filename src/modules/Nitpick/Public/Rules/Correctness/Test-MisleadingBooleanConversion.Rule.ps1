using namespace System.Collections
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Detects nonempty string literals converted to Boolean values.

.DESCRIPTION
    PowerShell converts every nonempty string to $true, including the string
    'false'. Reports direct casts and Boolean parameters with nonempty
    string-literal defaults. Parsing is appropriate when the string represents
    a textual Boolean value.
#>
function Test-MisleadingBooleanConversion {
    [CmdletBinding(DefaultParameterSetName='ScriptBlockAst')]
    [OutputType([object[]], [hashtable])]
    param(
        [Parameter(Mandatory,ParameterSetName='ScriptBlockAst')]
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst] $ScriptBlockAst,

        [Parameter(ParameterSetName='ScriptBlockAst')]
        [IDictionary] $Context,

        [Parameter(Mandatory,ParameterSetName='Details')]
        [switch] $Details
    )

    $Command = $PSCmdlet.MyInvocation.MyCommand
    $RuleName = if ($Command.Noun) { $Command.Noun } else { $Command.Name }
    $RuleId = "Nitpick/$RuleName"
    $Metadata = [pscustomobject]@{
        Name = $RuleName
        CommandName = $Command.Name
        Category = 'Correctness'
        Description = 'Detects nonempty string values converted to Boolean.'
        Severity = 'Warning'
        Explanation = "PowerShell converts every nonempty string to `$true, including strings such as 'false'. Use Boolean parsing when the string represents a textual Boolean value."
    }

    if ($Details) { return $Metadata }

    $Behavior = $Context.RuleBehavior
    $ShouldRecurse =
        if ($null -eq $Behavior.SearchNestedScriptBlocks) { $false }
        else { $Behavior.SearchNestedScriptBlocks }
    $OutputAs =
        if ($null -eq $Behavior.OutputType) { 'DiagnosticRecord' }
        else { $Behavior.OutputType }

    $BooleanDefaults = @{}
    $ScriptBlockAst.FindAll({
        param($Node)

        $Node -is [ParameterAst] -and
            $Node.StaticType -eq [bool] -and
            $Node.DefaultValue -is [StringConstantExpressionAst] -and
            $Node.DefaultValue.Value.Length -gt 0
    }, $ShouldRecurse) | ForEach-Object {
        $Default = $_.DefaultValue
        $BooleanDefaults["$($Default.Extent.StartOffset):$($Default.Extent.EndOffset)"] = $_
    }

    $Candidates = @(
        $ScriptBlockAst.FindAll({
            param($Node)

            $Node -is [ConvertExpressionAst] -and
                $Node.Type.TypeName.FullName -in 'bool', 'System.Boolean' -and
                $Node.Child -is [StringConstantExpressionAst] -and
                $Node.Child.Value.Length -gt 0
        }, $ShouldRecurse) | Where-Object {
            -not $BooleanDefaults.ContainsKey("$($_.Extent.StartOffset):$($_.Extent.EndOffset)")
        }

        $BooleanDefaults.Values | ForEach-Object { $_.DefaultValue }
    )

    foreach ($Candidate in $Candidates) {
        $FilePath = if ($Candidate.Extent.FileName) {
            $Candidate.Extent.FileName
        } else {
            '<ScriptBlock>'
        }

        New-NitpickFinding `
            -RuleId $RuleId `
            -Message 'A nonempty string converts to $true, even when its text is false.' `
            -ViolationExtent $Candidate.Extent `
            -Severity $Metadata.Severity `
            -ScriptPath $FilePath `
            -Explanation $Metadata.Explanation `
            -OutputAs $OutputAs
    }
}
