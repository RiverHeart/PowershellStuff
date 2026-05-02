
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
