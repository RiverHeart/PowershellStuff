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
            SizetoContent = 'WidthAndHeight'
        }
        Register-WPFObject $Name $Window
        Update-WPFObject $Window $ScriptBlock
        Set-WPFObjectType $Window 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Window) with error: $_"
    }
    return $Window
}
