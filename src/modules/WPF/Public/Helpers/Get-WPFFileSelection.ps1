# WORK IN PROGRESS
function Get-FileSelection {
    [CmdletBinding()]
    [OutputType([string])]
    [Alias('FileSelect')]
    param(
        [ValidateNotNullOrEmpty()]
        [string[]] $Filters,

        # Quick Filters
        [switch] $All,
        [switch] $Image
    )

    if ($All) {
        $Filters += @('All Files (*.*)|*.*')
    }
    if ($Image) {
        $Filters += @(
            'Image Files (*.jpg;*.png;*.bmp;*.ico;*.tiff;*.gif)|*.jpg;*.png;*.bmp;*.ico;*.tiff;*.gif'
            'JPEG (*.jpg)|*.jpg'
            'PNG (*.png)|*.png)'
            'Bitmap (*.bmp)|*.bmp'
            'Icon (*.ico)|*.ico'
            'TIFF (*.tiff)|*.tiff'
            'GIF (*.gif)|*.gif'
            'WebP (*.webp)|*.webp'
        )
    }

    # If nothing was provided
    if (-not $Filters) {
        $Filters = @('All Files (*.*)|*.*')
    }

    try {
        $Window = New-WPFWindow 'FileSelectionWindow' {}
        $Window.TopMost = $True

        $OpenFileDialog = [Microsoft.Win32.OpenFileDialog]::new()
        $OpenFileDialog.Filter = $Filters -join '|'

        if ($OpenFileDialog.ShowDialog($Window) -eq $True) {
            return $OpenFileDialog.FileName
        }
        return ''
    } finally {
        if ($Window) { $Window.Close() }
    }
}
