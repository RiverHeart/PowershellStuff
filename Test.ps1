function Foo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Bar
    )

    if (-not ($True -is [bool])) {

    }
    $Foo = 'Foo'
}
