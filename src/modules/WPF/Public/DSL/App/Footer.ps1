<#
.SYNOPSIS
    Routes a block into the current App footer host.

.DESCRIPTION
    Footer is a lightweight logical block for App shells. It creates the App
    footer host on first use, docks that host above the status bar, and
    forwards its scriptblock to the footer host.
#>
function Footer {
    [CmdletBinding()]
    [Alias('-Footer')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name 'Footer'
        return
    }

    $Parent = $PSCmdlet.GetVariableValue('this')
    if (-not $Parent -or -not ($Parent -is [System.Windows.Window])) {
        Write-Error 'Footer requires an App shell window as the current DSL parent.'
        return
    }

    $ContentHost = Get-WPFAppContentHost -Window $Parent
    if (-not $ContentHost) {
        Write-Error 'Footer requires an App shell with a content host.'
        return
    }

    $FooterHost = Get-WPFAppFooterHost -Window $Parent
    if (-not $FooterHost) {
        $ContextId = Resolve-WPFControlContextId -InputObject $Parent
        $FooterHost = [System.Windows.Controls.StackPanel] @{
            Name = "$(($Parent.Name))Footer"
            Margin = '12,0,12,12'
        }

        if ($ContextId) {
            Register-WPFObject -Name $FooterHost.Name -InputObject $FooterHost -ContextId $ContextId
        } else {
            Register-WPFObject -Name $FooterHost.Name -InputObject $FooterHost
        }

        Add-WPFType $FooterHost 'Control'
        $Parent | Add-Member -NotePropertyName '_WPFAppFooter' -NotePropertyValue $FooterHost -Force
        Add-WPFAppRootChild -Window $Parent -Child $FooterHost -Placement 'Footer'
    }

    Update-WPFObject $FooterHost $ScriptBlock
}
