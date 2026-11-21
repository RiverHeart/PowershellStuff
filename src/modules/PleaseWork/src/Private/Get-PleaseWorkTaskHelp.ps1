using namespace System.Collections.Generic
using namespace System.Collections.ObjectModel
using namespace System.Management.Automation.Language
using namespace System.Reflection

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
    param(
        [Parameter(Mandatory)]
        [ScriptBlockAst] $ScriptBlockAst
    )

    $Help = $ScriptBlockAst.GetHelpContent()
    if ($null -ne $Help) {
        Write-Output $Help -NoEnumerate
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

    $CommentHelp = [CommentHelpInfo]::new()
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
        [StringComparer]::OrdinalIgnoreCase
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
    foreach ($Link in $CommandHelp.relatedLinks.navigationLink) {
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
        $Property = [CommentHelpInfo].GetProperty(
            $PropertyName,
            [BindingFlags] (
                [BindingFlags]::Public -bor
                [BindingFlags]::NonPublic -bor
                [BindingFlags]::Instance
            )
        )
        $Property.SetValue($CommentHelp, $HelpProperties[$PropertyName])
    }

    Write-Output $CommentHelp -NoEnumerate
}
