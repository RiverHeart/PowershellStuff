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
        [ArgumentCompleter({ Complete-WPFHandler @args })]
        [string] $Event,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    return @{
        Event = $Event
        ScriptBlock = $ScriptBlock
    } | Set-WPFObjectType -Type 'Handler' -PassThru
}
