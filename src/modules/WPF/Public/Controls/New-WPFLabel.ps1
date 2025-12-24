function New-WPFLabel {
    [Alias('Label')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $Content,

        [scriptblock] $ScriptBlock
    )

    $Label = [System.Windows.Controls.Label] @{
        Name = $Name
        Content = $Content
    }
    if ($ScriptBlock) {
        Update-WPFObject $Label $ScriptBlock
    }
    Set-WPFObjectType $Label 'Control'

    return $Label
}
