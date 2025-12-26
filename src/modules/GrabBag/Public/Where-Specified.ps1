function Where-Specified {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(ValueFromPipeline)]
        [object] $InputObject,

        [string[]] $Include,
        [string[]] $Exclude
    )

    process {
        $IsIncluded = if ($Include) { $_ -in $Include } else { $True }
        $IsExcluded = if ($Exclude) { $_ -in $Exclude } else { $False }
        if ($IsIncluded -and -not $IsExcluded) {
            Write-Output $InputObject
        }
    }
}
