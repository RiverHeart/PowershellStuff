using namespace System.Collections
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Completes task names for Invoke-PleaseWork.
#>
function Complete-PleaseWorkTask {
    [CmdletBinding()]
    [OutputType([CompletionResult[]])]
    param(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [CommandAst] $CommandAst,
        [IDictionary] $FakeBoundParameters
    )

    try {
        $TaskFilePath = Resolve-TaskFilePath -Path $FakeBoundParameters['TaskFile']
        foreach ($Declaration in (Get-TaskFileDeclaration -Path $TaskFilePath)) {
            if ($Declaration.Name.StartsWith($WordToComplete, [StringComparison]::OrdinalIgnoreCase)) {
                Write-Output ([CompletionResult]::new(
                    $Declaration.Name,
                    $Declaration.Name,
                    [CompletionResultType]::ParameterValue,
                    $Declaration.Name
                ))
            }
        }

        if ('help'.StartsWith($WordToComplete, [StringComparison]::OrdinalIgnoreCase)) {
            Write-Output ([CompletionResult]::new(
                'help',
                'help',
                [CompletionResultType]::ParameterValue,
                'Display help information'
            ))
        }
    } catch {
        return
    }
}
