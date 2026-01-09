<#
.SYNOPSIS
    Prompts the user to select a file from the file browser.

.DESCRIPTION
    Prompts the user to select a file from the file browser.

.NOTES
    The reason I'm use the verb `Get` instead of `Select` is
    because
        1) We are not the ones doing the selecting, the user is
        2) The `Get-Credential` cmdlet prompts the user similarly.
#>
function Get-WPFFileSelection {
    [CmdletBinding()]
    [OutputType([string])]
    [Alias('FileBrowse')]
    param(
        [ArgumentCompleter({ Complete-WPFFileFilter @args })]
        [ValidateNotNullOrEmpty()]
        [string[]] $Filter
    )

    # Construct $Filter

    # If nothing was provided
    if (-not $Filter) {
        $Filter = @('All Files (*.*)|*.*')
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
