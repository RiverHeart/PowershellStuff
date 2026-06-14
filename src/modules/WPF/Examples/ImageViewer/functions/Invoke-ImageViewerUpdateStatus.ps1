
function Invoke-ImageViewerUpdateStatus {
    [CmdletBinding()]
    param(
        [System.Windows.Window] $Window
    )

    if ($null -eq $Window) {
        $Window = Get-WPFWindow -ErrorAction SilentlyContinue
    }
    if ($null -eq $Window -or $null -eq $Window.Tag) {
        return
    }

    $ContextId = Get-WPFContextId -InputObject $Window
    $State = $Window.Tag
    $FileLabel = Reference 'StatusFileLabel' -ContextId $ContextId
    $IndexLabel = Reference 'StatusIndexLabel' -ContextId $ContextId
    $DetailsLabel = Reference 'StatusDetailsLabel' -ContextId $ContextId
    $ZoomLabel = Reference 'StatusZoomLabel' -ContextId $ContextId

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
    $Source = (Reference 'Viewer' -ContextId $ContextId).Source

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
