function Invoke-ImageViewerToggleTheme {
    [CmdletBinding()]
    param()

    $Window = Reference 'Window'
    Toggle-WPFTheme -Root $Window
    Invoke-ImageViewerUpdateNavigationIconStyle
}

# NOTE: Regrettably, the only way I've found to support Light/Dark themes
# is to update the icon colors manually.
function Invoke-ImageViewerUpdateNavigationIconStyle {
    [CmdletBinding()]
    param()

    $Window = Reference 'Window'
    $State = $Window.Tag
    $IconBrushKey = if ($State.IsFileLoaded) { 'Foreground' } else { 'DisabledForeground' }
    $IconBrush = $Window.TryFindResource($IconBrushKey)

    if (-not $IconBrush) {
        $IconBrush = if ($State.IsFileLoaded) {
            [System.Windows.Media.Brushes]::White
        } else {
            [System.Windows.Media.Brushes]::Gray
        }
    }

    foreach ($ButtonName in @('BackButton', 'ForwardButton')) {
        $Button = Reference $ButtonName
        if (-not $Button) { continue }

        $Path = $Button.Content
        if ($Path -is [System.Windows.Shapes.Path]) {
            $Path.Fill = $IconBrush
            $Path.Stroke = $IconBrush
        }
    }
}

function Invoke-ImageViewerUpdateStatus {
    [CmdletBinding()]
    param()

    $State = (Reference 'Window').Tag
    $FileLabel = Reference 'StatusFileLabel'
    $IndexLabel = Reference 'StatusIndexLabel'
    $DetailsLabel = Reference 'StatusDetailsLabel'
    $ZoomLabel = Reference 'StatusZoomLabel'

    if (-not $State.IsFileLoaded -or -not $State.FileNavigator -or -not $State.FileNavigator.CurrentFile) {
        $FileLabel.Content = 'No image loaded'
        $IndexLabel.Content = '0/0'
        $DetailsLabel.Content = '-'
        $ZoomLabel.Content = '100%'
        return
    }

    $CurrentFile = $State.FileNavigator.CurrentFile
    $CurrentIndex = $State.FileNavigator.Index + 1
    $TotalFiles = $State.FileNavigator.Files.Count
    $Source = (Reference 'Viewer').Source

    $Dimensions = '-'
    if ($Source -is [System.Windows.Media.Imaging.BitmapSource]) {
        $Dimensions = "$($Source.PixelWidth)x$($Source.PixelHeight)"
    }

    $ZoomPercent = [Math]::Round([double] $State.ZoomLevel * 100)

    $FileLabel.Content = $CurrentFile.Name
    $IndexLabel.Content = "$CurrentIndex/$TotalFiles"
    $DetailsLabel.Content = $Dimensions
    $ZoomLabel.Content = "$ZoomPercent%"
}

function Invoke-ImageViewerSetZoom {
    [CmdletBinding()]
    param(
        [double] $Delta = 0,

        [switch] $Reset
    )

    $State = (Reference 'Window').Tag
    $Viewer = Reference 'Viewer'

    $ZoomLevel = if ($Reset) { 1.0 } else { [double] $State.ZoomLevel + $Delta }
    $ZoomLevel = [Math]::Max(0.10, [Math]::Min(8.00, $ZoomLevel))
    $ZoomLevel = [Math]::Round($ZoomLevel, 2)
    $State.ZoomLevel = $ZoomLevel

    if (-not ($Viewer.LayoutTransform -is [System.Windows.Media.ScaleTransform])) {
        $Viewer.LayoutTransform = [System.Windows.Media.ScaleTransform]::new(1.0, 1.0)
    }

    $Transform = [System.Windows.Media.ScaleTransform] $Viewer.LayoutTransform
    $Transform.ScaleX = $ZoomLevel
    $Transform.ScaleY = $ZoomLevel

    Invoke-ImageViewerUpdateStatus
}

function Invoke-ImageViewerLoadFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $FileName
    )

    if (-not (Test-Path -Path $FileName -PathType Leaf)) {
        Write-Warning "File not found: '$FileName'"
        return
    }

    $Window = Reference 'Window'
    $Viewer = Reference 'Viewer'

    try {
        $Viewer.Source = $FileName

        $State = $Window.Tag
        $State.FileNavigator = New-WPFFileNavigator -Path $FileName -Category Image
        $State.IsFileLoaded = $true

        Invoke-ImageViewerUpdateNavigationIconStyle
        Invoke-ImageViewerSetZoom -Reset
        Invoke-ImageViewerUpdateStatus
    } catch {
        Write-Warning "Failed to load image '$FileName': $_"
    }
}

function Invoke-ImageViewerNavigate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Back', 'Forward')]
        [string] $Direction
    )

    $State = (Reference 'Window').Tag
    if (-not $State.IsFileLoaded) { return }
    $Navigator = $State.FileNavigator
    if (-not $Navigator.CurrentFile) { return }

    if ($Direction -eq 'Back') { $Navigator.MovePrevious() } else { $Navigator.MoveNext() }
    (Reference 'Viewer').Source = $Navigator.CurrentFile.FullName
    Invoke-ImageViewerUpdateStatus
}
