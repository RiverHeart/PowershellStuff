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
