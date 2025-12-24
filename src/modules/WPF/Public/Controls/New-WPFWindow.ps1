function New-WPFWindow {
    [Alias('Window')]
    [OutputType([System.Windows.Window])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Title,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    $Window = [System.Windows.Window] @{
        Name = $Name
        Title = $Title
    }
    Register-WPFObject $Name $Window
    Update-WPFObject $Window $ScriptBlock
    Set-WPFObjectType $Window 'Control'
    return $Window
}
