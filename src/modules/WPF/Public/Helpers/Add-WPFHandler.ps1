<#
.SYNOPSIS
    Returns an annotated hashtable containing the event and
    scriptblock that should be added to the control as an
    event handler.

.DESCRIPTION
    Returns an annotated hashtable containing the event and
    scriptblock that should be added to the control as an
    event handler.

    The annotation 'Handler' tells the caller what type of
    result this is.

.EXAMPLE
    Adds a click handler to a button that writes "Button clicked"
    to the console.

    Button "Example" "Example" {
        Handler "Click" {
            Write-Host "Button clicked"
        }
    }
#>
function Add-WPFHandler {
    [CmdletBinding()]
    [Alias('Handler')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
            param(
                [string] $CommandName,
                [string] $ParameterName,
                [string] $WordToComplete,
                [System.Management.Automation.Language.CommandAst] $CommandAst,
                [System.Collections.IDictionary] $FakeBoundParameters
            )

            $Params = Get-FunctionParam TabExpansion2

            # Confusing. When typing `Handler X` the `Handler` function hasn't become
            # a CommandAst object yet. Once the Handler has a scriptblock defined
            # such as `Handler X {}` it becomes one. Therefore we need to get the last
            # CommandAst that isn't the handler itself to account for the two scenarios.
            $ParentNode = $Params.Ast.FindAll({
                param($AstNode)
                $AstNode -is [System.Management.Automation.Language.CommandAst] -and
                $AstNode.Extent.StartOffset -le $Params.PositionOfCursor.Offset -and
                $Params.PositionOfCursor.Offset -le $AstNode.Extent.EndOffset
            }, <# recurse #> $True) |
                Where-Object { $_.GetCommandName() -ne 'Handler' } |
                Select-Object -Last 1

            $Control = $ParentNode.GetCommandName()
            switch ($Control) {
                'Button' { [System.Windows.Controls.Button].GetEvents().Name }
                default {}
            }
        })]
        [string] $Event,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    return @{
        Event = $Event
        ScriptBlock = $ScriptBlock
    } | Set-WPFObjectType -Type 'Handler' -PassThru
}
