<#
.SYNOPSIS
    Routes a block into the current App content host.

.DESCRIPTION
    Content is a lightweight logical block for App shells. It does not create
    a separate visual container; it forwards its scriptblock to the app's main
    content host so users can group body content explicitly when they want to.
#>
function Content {
    [CmdletBinding()]
    [Alias('-Content')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name 'Content'
        return
    }

    $Parent = $PSCmdlet.GetVariableValue('this')
    if (-not $Parent -or -not ($Parent -is [System.Windows.Window])) {
        Write-Error 'Content requires an App shell window as the current DSL parent.'
        return
    }

    $ContentHost = Get-WPFAppContentHost -Window $Parent
    if (-not $ContentHost) {
        Write-Error 'Content requires an App shell with a content host.'
        return
    }

    Update-WPFObject $ContentHost $ScriptBlock
}
