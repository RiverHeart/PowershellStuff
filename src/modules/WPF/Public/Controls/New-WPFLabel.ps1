function New-WPFLabel {
    [Alias('Label')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    $Label = [System.Windows.Controls.Label] @{
        Name = $Name
    }
    Register-WPFObject $Name $Label
    if ($ScriptBlock) {
        Update-WPFObject $Label $ScriptBlock
    }
    Set-WPFObjectType $Label 'Control'

    return $Label
}
