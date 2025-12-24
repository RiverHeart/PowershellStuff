function New-WPFTextBox {
    [Alias('TextBox')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [scriptblock] $ScriptBlock
    )

    $TextBox = [System.Windows.Controls.TextBox] @{
        Name = $Name
    }
    if ($ScriptBlock) {
        Update-WPFObject $TextBox $ScriptBlock
    }
    Set-WPFObjectType $TextBox 'Control'

    return $TextBox
}
