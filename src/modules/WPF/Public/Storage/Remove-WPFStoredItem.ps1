<#
.SYNOPSIS
    Removes an item from WPF application storage.
#>
function Remove-WPFStoredItem {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [psobject] $Storage,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [ValidateSet('CliXml', 'Json')]
        [string] $Format = 'Json'
    )

    $ItemPath = Resolve-WPFStorageItemPath -Storage $Storage -Name $Name -Format $Format
    if ((Test-Path -LiteralPath $ItemPath -PathType Leaf) -and
        $PSCmdlet.ShouldProcess($ItemPath, 'Remove stored item')
    ) {
        Remove-Item -LiteralPath $ItemPath -Force
    }
}
