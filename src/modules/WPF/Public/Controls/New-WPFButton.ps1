function New-WPFButton {
    [Alias('Button')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $Content,

        [scriptblock] $ScriptBlock
    )

    $Button = [System.Windows.Controls.Button] @{
        Name = $Name
        Content = $Content
    }
    Register-WPFObject $Name $Button
    if ($ScriptBlock) {
        Update-WPFObject $Button $ScriptBlock
    }
    Set-WPFObjectType $Button 'Control'

    return $Button
}
