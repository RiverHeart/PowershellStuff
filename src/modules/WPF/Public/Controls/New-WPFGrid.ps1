
function New-WPFGrid {
    [Alias('Grid')]
    [OutputType([System.Windows.Controls.Grid])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    $Grid = [System.Windows.Controls.Grid]::new()
    $Grid.Name = $Name
    Register-WPFObject $Name $Grid
    Update-WPFObject $Grid $ScriptBlock
    Set-WPFObjectType $Grid 'Control'
    return $Grid
}
