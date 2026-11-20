using namespace System.Collections.Generic
using namespace System.Collections.ObjectModel

<#
.SYNOPSIS
    Gets comment help from a TaskFile task body.

.DESCRIPTION
    Uses the scriptblock AST help parser and falls back to defining a private
    function for PowerShell 5.1, where GetHelpContent does not return task-body
    comment help consistently.

.PARAMETER ScriptBlockAst
    The task-body scriptblock AST.

.EXAMPLE
    Get-PleaseWorkTaskHelp -ScriptBlockAst $TaskBodyAst

    Returns comment help metadata without executing the task body.

.NOTES
    Examples run in the PleaseWork module's scope.
#>
function Get-PleaseWorkTaskHelp {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Language.CommentHelpInfo])]
    param (
        [Parameter(Mandatory)]
        [System.Management.Automation.Language.ScriptBlockAst] $ScriptBlockAst
    )

    $Help = $ScriptBlockAst.GetHelpContent()
    if ($null -ne $Help) {
        Write-Output -NoEnumerate $Help
        return
    }
    if (-not $ScriptBlockAst.Extent.Text.Contains('<#')) {
        return
    }

    $HelpFunctionName = 'PleaseWorkHelp' + [guid]::NewGuid().ToString('N')
    $Definition = [scriptblock]::Create(
        "function $HelpFunctionName $($ScriptBlockAst.Extent.Text)"
    )
    $HelpModule = New-Module -ScriptBlock $Definition
    $CommandHelp = & $HelpModule {
        param ($Name)
        Get-Help -Name $Name -Full
    } $HelpFunctionName
    if ($null -eq $CommandHelp -or
        [string]::IsNullOrWhiteSpace([string] $CommandHelp.Synopsis)
    ) {
        return
    }

    $CommentHelp = [System.Management.Automation.Language.CommentHelpInfo]::new()
    $Synopsis = [string] $CommandHelp.Synopsis
    $Description = @(
        $CommandHelp.Description |
            ForEach-Object {
                if ($null -ne $_.Text) { $_.Text } else { $_ }
            }
    ) -join [Environment]::NewLine
    $Notes = @(
        $CommandHelp.alertSet |
            ForEach-Object {
                if ($null -ne $_.alert.Text) { $_.alert.Text } else { $_.alert }
            }
    ) -join [Environment]::NewLine

    $Examples = [List[string]]::new()
    foreach ($Example in @($CommandHelp.examples.example)) {
        if ($null -ne $Example.code) {
            $Examples.Add([string] $Example.code)
        }
    }

    $Parameters = [Dictionary[string, string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    foreach ($Parameter in @($CommandHelp.parameters.parameter)) {
        $ParameterDescription = @(
            $Parameter.description |
                ForEach-Object {
                    if ($null -ne $_.Text) { $_.Text } else { $_ }
                }
        ) -join [Environment]::NewLine
        $Parameters[[string] $Parameter.name] = $ParameterDescription
    }

    $Links = [List[string]]::new()
    foreach ($Link in @($CommandHelp.relatedLinks.navigationLink)) {
        if ($null -ne $Link.linkText) {
            $Links.Add([string] $Link.linkText)
        }
    }

    $HelpProperties = @{
        Synopsis = $Synopsis
        Description = $Description
        Notes = $Notes
        Examples = $Examples.AsReadOnly()
        Parameters = $Parameters
        Links = $Links.AsReadOnly()
    }
    foreach ($PropertyName in $HelpProperties.Keys) {
        $Property = [System.Management.Automation.Language.CommentHelpInfo].GetProperty(
            $PropertyName,
            [System.Reflection.BindingFlags] (
                [System.Reflection.BindingFlags]::Public -bor
                [System.Reflection.BindingFlags]::NonPublic -bor
                [System.Reflection.BindingFlags]::Instance
            )
        )
        $Property.SetValue($CommentHelp, $HelpProperties[$PropertyName])
    }

    Write-Output -NoEnumerate $CommentHelp
}
