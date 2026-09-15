<#
.SYNOPSIS
    Resolves the path to a stored item in application storage.

.EXAMPLE
    $Storage = New-WPFAppStorage -Application 'MyApp'
    $ItemPath = Resolve-WPFStorageItemPath -Storage $Storage -Name 'MyItem'
#>
function Resolve-WPFStorageItemPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [psobject] $Storage,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [ValidateSet('CliXml', 'Json')]
        [string] $Format = 'Json'
    )

    if ($Storage.PSObject.TypeNames -notcontains 'WPF.ApplicationStorage') {
        Write-Error 'Storage must be created by New-WPFAppStorage.' -Category InvalidOperation
        return
    }

    if ($Name -in '.', '..' -or
        $Name.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
        $Name.EndsWith('.') -or
        $Name.EndsWith(' ')
    ) {
        Write-Error "Storage item name '$Name' is not a valid file name." -Category InvalidArgument
        return
    }

    $Extension = switch ($Format) {
        'CliXml' { 'clixml' }
        'Json' { 'json' }
    }

    Join-Path -Path $Storage.RootPath -ChildPath "$Name.$Extension"
}
