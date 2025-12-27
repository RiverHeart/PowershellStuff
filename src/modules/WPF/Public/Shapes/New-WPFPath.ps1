function New-WPFPath {
    [CmdletBinding()]
    [Alias('Path')]
    [OutputType([System.Windows.Shapes.Path])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [scriptblock] $ScriptBlock
    )

    if (-not (Test-Path $Path)) {
        Write-Error "File not found '$Path'"
        return
    }

    [xml] $SvgDocument = Get-Content -Raw $Path

    $Geometry = [System.Windows.Media.Geometry]::Parse($SvgDocument.svg.path.d)
    $Geometry.Freeze()  # Make unmodifiable for performance.

    $PathGeo = [System.Windows.Shapes.Path] @{
        Data = $Geometry
        Stroke = [System.Windows.Media.Brushes]::Black
        Fill = [System.Windows.Media.Brushes]::Black
        StrokeThickness = 1
        Stretch = [System.Windows.Media.Stretch]::Uniform
    }

    if ($ScriptBlock) {
        Update-WPFObject $PathGeo $ScriptBlock
    }
    Set-WPFObjectType $PathGeo 'Shape'

    return $PathGeo
}
