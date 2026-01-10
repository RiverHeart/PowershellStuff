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

.EXAMPLE
    Basic usage, creates a file browser that defaults to single select
    for any file type.

    Get-WPFFileSelection

.EXAMPLE
    Create a file browser that automatically sets up filters for the given
    file types and several image types.

    Get-WPFFileSelection -Type All, PNG, JPEG, GIF, TIFF

.EXAMPLE
    Create a file browser that automatically sets up filters for the given
    file types and category which contains several image types.

    Get-WPFFileSelection -Type All -Category Image
#>
function Get-WPFFileSelection {
    [CmdletBinding()]
    [OutputType([string])]
    [Alias('FileBrowse')]
    param(
        [ArgumentCompleter({ Complete-WPFFileInfo -Type })]
        [ValidateNotNullOrEmpty()]
        [string[]] $Type,

        [ArgumentCompleter({ Complete-WPFFileInfo -Category })]
        [ValidateNotNullOrEmpty()]
        [string[]] $Category,

        # Hopefully a last resort
        [ArgumentCompleter({ Complete-WPFFileFilter @args })]
        [ValidateNotNullOrEmpty()]
        [string[]] $Filter,

        [ValidateNotNullOrEmpty()]
        [string] $Title = 'Select a file',

        [switch] $Multiselect,

        # Not implemented right now
        [System.Windows.Window] $Window

        # TODO: Implement me
        # [ArgumentCompleter({ Complete-WPFFileInfo -Type })]
        # [ValidateNotNullOrEmpty()]
        # [string[]] $Exclude
    )

    $CreatedWindow = $False

    if ($Type -or $Category) {
        $GetFileInfoParams = @{}
        if ($Type) { $GetFileInfoParams.Type = $Type }
        if ($Category) { $GetFileInfoParams.Category = $Category }
        $Filter += Get-WPFFileInfo @GetFileInfoParams | Select-Object -ExpandProperty Filter
        if (-not $Filter) {
            Write-Error "Failed to find any filters."
            return ''
        }
    } else {
        $Filter = @('All Files (*.*)|*.*')
    }

    try {
        $OpenFileDialog = [Microsoft.Win32.OpenFileDialog]::new()
        $OpenFileDialog.Filter = $Filter -join '|'
        $OpenFileDialog.Title = $Title
        $OpenFileDialog.Multiselect = $MultiSelect

        # TODO: Maybe one day find a way to make this work...
        # if (-not $Window) {
        #     $CreatedWindow = $True
        #     $Window = New-WPFWindow 'FileSelectionWindow' {}
        #     $Window.TopMost = $True
        # }
        # $Window.Dispatcher.InvokeAsync({
        #     $Window.ShowDialog() | Out-Null
        # })
        # $Window.Dispatcher.Invoke({
        #     if ($OpenFileDialog.ShowDialog($Window) -eq $True) {
        #         return $OpenFileDialog.FileName
        #     }
        # })

        if ($Window -and $OpenFileDialog.ShowDialog() -eq $True) {
            return $OpenFileDialog.FileName
        } elseif ($OpenFileDialog.ShowDialog() -eq $True) {
            return $OpenFileDialog.FileName
        }
        return ''
    } finally {
        if ($CreatedWindow -and $Window) { $Window.Close() }
    }
}
