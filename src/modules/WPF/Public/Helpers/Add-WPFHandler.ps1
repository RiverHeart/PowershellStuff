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
    [Alias('Handler', 'When')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({ Complete-WPFEvent @args })]
        [string] $Event,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    return @{
        Event = $Event
        ScriptBlock = $ScriptBlock
    } | Add-WPFType -Type 'Handler' -PassThru
}
