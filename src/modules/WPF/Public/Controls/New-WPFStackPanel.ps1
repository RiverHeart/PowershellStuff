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

    $StackPanel = [System.Windows.Controls.StackPanel]::new()
    $StackPanel.Name = $Name
    Update-WPFObject $StackPanel $ScriptBlock
    Set-WPFObjectType $StackPanel 'Control'
    return $StackPanel
}
