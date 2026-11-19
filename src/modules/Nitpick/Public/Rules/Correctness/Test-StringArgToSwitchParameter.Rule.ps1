using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Detects Boolean-like string arguments immediately following known switch parameters.

.DESCRIPTION
    A switch parameter is enabled by its presence. A following string such as
    'false' is a separate command argument, not a false value for the switch.
    The rule reports only when command parameter metadata identifies the switch.
#>
function Test-StringArgToSwitchParameter {
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
        Description = 'Detects Boolean-like strings passed after known switch parameters.'
        Severity = 'Information'
        Explanation = "A switch parameter is enabled by its presence. A following string is a separate argument; use an explicit value such as -Force:`$false if you intended to disable the switch."
    }

    if ($Details) { return $Metadata }

    $Behavior = $Context.RuleBehavior
    $ShouldRecurse =
        if ($null -eq $Behavior.SearchNestedScriptBlocks) { $false }
        else { $Behavior.SearchNestedScriptBlocks }
    $OutputAs =
        if ($null -eq $Behavior.OutputType) { 'DiagnosticRecord' }
        else { $Behavior.OutputType }

    $LocalSwitches = @{}
    $Functions = $ScriptBlockAst.FindAll({
        param($Node)
        $Node -is [FunctionDefinitionAst]
    }, $ShouldRecurse)

    foreach ($Function in $Functions) {
        if (-not $Function.Body.ParamBlock) { continue }
        $Names = @(
            $Function.Body.ParamBlock.Parameters | Where-Object {
                $_.StaticType -eq [switch]
            } | ForEach-Object {
                $_.Name.VariablePath.UserPath
                foreach ($Attribute in $_.Attributes) {
                    if ($Attribute -is [AttributeAst] -and $Attribute.TypeName.Name -eq 'Alias') {
                        $Attribute.PositionalArguments | ForEach-Object { $_.Value }
                    }
                }
            }
        )
        if ($Names.Count -gt 0) { $LocalSwitches[$Function.Name] = $Names }
    }

    $Commands = $ScriptBlockAst.FindAll({
        param($Node)
        $Node -is [CommandAst]
    }, $ShouldRecurse)

    foreach ($CommandAst in $Commands) {
        $CommandName = $CommandAst.GetCommandName()
        if (-not $CommandName) { continue }

        $KnownSwitches = [List[string]]::new()
        if ($LocalSwitches.ContainsKey($CommandName)) {
            foreach ($SwitchName in $LocalSwitches[$CommandName]) {
                [void] $KnownSwitches.Add($SwitchName)
            }
        }

        if ($KnownSwitches.Count -eq 0) {
            $CommandInfo = Get-Command `
                -Name $CommandName `
                -ErrorAction SilentlyContinue

            foreach ($ResolvedCommand in $CommandInfo) {
                if ($ResolvedCommand -is [AliasInfo] -and $ResolvedCommand.ResolvedCommand) {
                    $ResolvedCommand = $ResolvedCommand.ResolvedCommand
                }

                if (-not $ResolvedCommand.Parameters) { continue }

                foreach ($ParameterMetadata in $ResolvedCommand.Parameters.Values) {
                    if ($ParameterMetadata.ParameterType -eq [SwitchParameter]) {
                        [void] $KnownSwitches.Add($ParameterMetadata.Name)

                        foreach ($Alias in $ParameterMetadata.Aliases) {
                            [void] $KnownSwitches.Add($Alias)
                        }
                    }
                }
            }
        }

        if ($KnownSwitches.Count -eq 0) { continue }

        for ($Index = 0; $Index -lt $CommandAst.CommandElements.Count - 1; $Index++) {
            $Parameter = $CommandAst.CommandElements[$Index]
            $Argument = $CommandAst.CommandElements[$Index + 1]

            if ($Parameter -isnot [CommandParameterAst] -or
                $Parameter.Argument -or
                $Parameter.ParameterName -notin $KnownSwitches -or
                $Argument -isnot [StringConstantExpressionAst] -or
                $Argument.Value -notmatch '\A(?:false|0|no|off)\z'
            ) {
                continue
            }

            $FilePath = if ($Argument.Extent.FileName) {
                $Argument.Extent.FileName
            } else {
                '<ScriptBlock>'
            }

            New-NitpickFinding `
                -RuleId $RuleId `
                -Message "The string '$($Argument.Value)' is a separate argument; it does not set the -$($Parameter.ParameterName) switch to false." `
                -ViolationExtent $Argument.Extent `
                -Severity $Metadata.Severity `
                -ScriptPath $FilePath `
                -Explanation $Metadata.Explanation `
                -OutputAs $OutputAs
        }
    }
}
