<#
.SYNOPSIS
    Creates a new WPF Path object from a given path.

.DESCRIPTION
    Creates a new WPF Path object from a given path.

    It works by parsing out the path mini-language that seems
    to be more or less compatible between SVG and XAML Geometry objects.

    This does not support converting more complex SVGs.

    As an example, the resulting object can either be manually
    assigned to a button's content property or added as child object
    for `Update-WPFObject` to handle.

.NOTES
    I prefer not to use third party libraries unless they are absolutely
    required so I'm willing to accept the limitations of the conversion
    strategy here.

    TODO: Should probably support some sort of resource lookup like
    with the controls. Or perhaps the first param can accept a name
    or path and the existence of a path separate determines whether
    it's treated as one or the other.

    Path 'arrow-left-solid-full.svg'  # Name reference
    Path './arrow-left-solid-full.svg'  # Path reference
#>
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

    if (-not $SvgDocument.svg.path.d) {
        Write-Error "Error: Could not find data property for SVG.`nExpected format: <svg><path d=`"path mini-language`"/></svg>"
    }

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
    Add-WPFType $PathGeo 'Shape'

    return $PathGeo
}
