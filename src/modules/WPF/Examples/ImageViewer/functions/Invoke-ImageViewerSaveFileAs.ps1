using namespace System.IO
using namespace System.Windows.Media.Imaging

function Invoke-ImageViewerSaveFileAs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [BitmapSource] $Image,

        [Parameter()]
        [string] $SourcePath,

        [Parameter()]
        [string] $InitialDirectory
    )

    $SaveFileDialog = [Microsoft.Win32.SaveFileDialog]::new()
    $SaveFileDialog.Filter = 'Image Files|*.bmp;*.jpg;*.jpeg;*.png;*.gif|All Files|*.*'
    if (-not [string]::IsNullOrWhiteSpace($SourcePath)) {
        $SaveFileDialog.FileName = [Path]::GetFileName($SourcePath)
    }

    if (-not [string]::IsNullOrWhiteSpace($InitialDirectory)) {
        $SaveFileDialog.InitialDirectory = $InitialDirectory
    } elseif (-not [string]::IsNullOrWhiteSpace($SourcePath)) {
        $SaveFileDialog.InitialDirectory = [Path]::GetDirectoryName($SourcePath)
    }

    if ($SaveFileDialog.ShowDialog() -ne $true) {
        Write-Debug "SaveFileDialog was cancelled by the user."
        return
    }

    $Extension = [Path]::GetExtension($SaveFileDialog.FileName).ToLowerInvariant()
    $Encoder = switch ($Extension) {
        '.bmp' { [BmpBitmapEncoder]::new() }
        { $_ -in @('.jpg', '.jpeg') } { [JpegBitmapEncoder]::new() }
        '.png' { [PngBitmapEncoder]::new() }
        '.gif' { [GifBitmapEncoder]::new() }
        default {
            Write-Error "Unsupported file extension: $($SaveFileDialog.FileName). Supported extensions are .bmp, .jpg, .jpeg, .png, .gif."
            return
        }
    }

    $Encoder.Frames.Add([BitmapFrame]::Create($Image))
    $FileStream = $null

    try {
        Write-Debug "Saving image to $($SaveFileDialog.FileName) with encoder $($Encoder.GetType().Name)."
        $FileStream = [File]::Open($SaveFileDialog.FileName, [FileMode]::Create)
        $Encoder.Save($FileStream)
        Write-Debug "Image saved successfully to $($SaveFileDialog.FileName)."
        return $SaveFileDialog.FileName
    } finally {
        if ($null -ne $FileStream) {
            $FileStream.Dispose()
        }
    }
}
