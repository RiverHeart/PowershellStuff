function New-WPFStackPanel {
    [Alias('StackPanel')]
    [OutputType([System.Windows.Controls.StackPanel])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    try {
        $StackPanel = [System.Windows.Controls.StackPanel]::new()
        $StackPanel.Name = $Name
        Register-WPFObject $Name $StackPanel
        Update-WPFObject $StackPanel $ScriptBlock
        Set-WPFObjectType $StackPanel 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (StackPanel) with error: $_"
    }
    return $StackPanel
}
