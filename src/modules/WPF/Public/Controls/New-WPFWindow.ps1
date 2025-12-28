function New-WPFWindow {
    [Alias('Window')]
    [OutputType([System.Windows.Window])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    try {
        $Window = [System.Windows.Window] @{
            Name = $Name
        }
        Register-WPFObject $Name $Window
        Update-WPFObject $Window $ScriptBlock
        if (-not $Window.Height -and -not $Window.Width){
            $Window.SizeToContent = 'WidthAndHeight'
        }
        Set-WPFObjectType $Window 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Window) with error: $_"
    }
    return $Window
}
