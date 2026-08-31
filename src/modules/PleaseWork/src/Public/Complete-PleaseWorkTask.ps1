<#
.SYNOPSIS
    Completes task names for Invoke-PleaseWork.
#>
function Complete-PleaseWorkTask {
    [CmdletBinding()]
    param(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [System.Management.Automation.Language.CommandAst] $CommandAst,
        [System.Collections.IDictionary] $FakeBoundParameters
    )

    try {
        $TaskFilePath = Resolve-TaskFilePath -Path $FakeBoundParameters['TaskFile']
        foreach ($Declaration in (Get-TaskFileDeclaration -Path $TaskFilePath)) {
            if ($Declaration.Name.StartsWith($WordToComplete, [StringComparison]::OrdinalIgnoreCase)) {
                [System.Management.Automation.CompletionResult]::new(
                    $Declaration.Name,
                    $Declaration.Name,
                    [System.Management.Automation.CompletionResultType]::ParameterValue,
                    $Declaration.Name
                )
            }
        }
        if ('help'.StartsWith($WordToComplete, [StringComparison]::OrdinalIgnoreCase)) {
            [System.Management.Automation.CompletionResult]::new(
                'help',
                'help',
                [System.Management.Automation.CompletionResultType]::ParameterValue,
                'Display help information'
            )
        }
    } catch {
        return @()
    }
}
