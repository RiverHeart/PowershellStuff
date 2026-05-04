<#!
.SYNOPSIS
    Copies WPF image content to the clipboard.

.DESCRIPTION
    Copies a WPF Image control's source, or a BitmapSource directly, to the
    system clipboard.

.EXAMPLE
    Copies the current image displayed by the Viewer control to the clipboard.

    Set-WPFClipboard -InputObject (Reference 'Viewer')
#>
function Set-WPFClipboard {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object] $InputObject
    )

    $BitmapSource = if ($InputObject -is [System.Windows.Controls.Image]) {
        $InputObject.Source
    } elseif ($InputObject -is [System.Windows.Media.Imaging.BitmapSource]) {
        $InputObject
    } else {
        Write-Error "Input object of type '$($InputObject.GetType().FullName)' is not a supported image type."
        return
    }

    if ($BitmapSource -isnot [System.Windows.Media.Imaging.BitmapSource]) {
        return
    }

    Write-Debug "Copying image to clipboard: $BitmapSource"

    # WARNING: Clipboard operations must be performed in an STA thread. If we're not currently in an STA thread,
    # we need to create a new STA thread to perform the operation. PowerShell Desktop runs in STA by default,
    # but PowerShell Core runs in MTA, so this check ensures compatibility across platforms.
    if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq [System.Threading.ApartmentState]::STA) {
        [System.Windows.Clipboard]::SetImage($BitmapSource)
        return
    }

    $state = [hashtable]::Synchronized(@{
        Bitmap = $BitmapSource
        Error  = $null
    })

    $threadProc = [System.Threading.ParameterizedThreadStart]{
        param($ThreadState)

        try {
            [System.Windows.Clipboard]::SetImage($ThreadState.Bitmap)
        } catch {
            $ThreadState.Error = $_
        }
    }

    $thread = [System.Threading.Thread]::new($threadProc)
    $thread.SetApartmentState([System.Threading.ApartmentState]::STA)
    $thread.Start($state)
    $thread.Join()

    if ($state.Error) {
        Write-Error -ErrorRecord $state.Error
    }
}
