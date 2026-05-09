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
    Create a file browser that automatically sets up filters for all known
    image file types.

    Get-WPFFileSelection -Category Image
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

    if ($Type -and $Category -and ($Type -contains 'All')) {
        throw [System.ArgumentException]::new("-Type 'All' cannot be combined with -Category. Use -Category by itself, or specify explicit types without 'All'.")
    }

    if ($Type -or $Category) {
        $DialogFilter = Resolve-WPFFileDialogFilter -Type $Type -Category $Category -Filter $Filter
        if (-not $DialogFilter) {
            Write-Error "Failed to find any filters."
            return ''
        }
    } elseif ($Filter) {
        $DialogFilter = Resolve-WPFFileDialogFilter -Filter $Filter
    } else {
        $DialogFilter = @('All Files (*.*)|*.*')
    }

    try {
        $OpenFileDialog = [Microsoft.Win32.OpenFileDialog]::new()
        $OpenFileDialog.Filter = $DialogFilter -join '|'
        $OpenFileDialog.FilterIndex = 1
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

        $DialogResult = if ($Window) {
            $OpenFileDialog.ShowDialog($Window)
        } else {
            $OpenFileDialog.ShowDialog()
        }

        if ($DialogResult -eq $True) {
            return $OpenFileDialog.FileName
        }
        return ''
    } finally {
        if ($CreatedWindow -and $Window) { $Window.Close() }
    }
}
