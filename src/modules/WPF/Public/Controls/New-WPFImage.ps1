function New-WPFImage {
    [CmdletBinding()]
    [Alias('Image')]
    [OutputType([System.Windows.Controls.Image])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [scriptblock] $ScriptBlock
    )

    if (-not (Test-Path $Path)) {
        Write-Error "File not found '$Path'"
        return
    }

    $Brush = [System.Windows.Media.Brushes]::Black
    $Pen = [System.Drawing.Pens]::Black

    [xml] $SvgDocument = Get-Content -raw $Path

    $Geometry = [System.Windows.Media.Geometry]::Parse($SvgDocument.svg.path.d)
    $Geometry.Freeze()  # Make unmodifiable for performance.

    $PathGeo = [System.Windows.Shapes.Path]::new()
    $PathGeo.Data = $Geometry

    $GeometryDrawing = [System.Windows.Media.GeometryDrawing]::new(
        $Brush,
        $Pen,
        $Geometry
    )

    $DrawingImage = [System.Windows.Media.DrawingImage]::new($GeometryDrawing)

    $Image = [System.Windows.Controls.Image] @{
        Name = $Name
        Source = $DrawingImage
    }
    Register-WPFObject $Name $Image
    if ($ScriptBlock) {
        Update-WPFObject $Image $ScriptBlock
    }
    Set-WPFObjectType $Image 'Control'

    return $Image
}
