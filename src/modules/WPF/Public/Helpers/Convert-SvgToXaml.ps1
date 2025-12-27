function Convert-SvgToXaml {
    [CmdletBinding()]
    param(
        [string] $Path
    )

    process {
        foreach ($SvgFile in $Path) {
            if (-not (Test-Path $SvgFile)) {
                Write-Error "File not found '$SvgFile'"
                return
            }

            #$FileStream = [System.IO.FileStream]::new($SvgFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
            [xml] $SvgDocument = Get-Content -raw $SvgFile
        }
    }
}
