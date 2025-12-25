function New-WPFTextBox {
    [Alias('TextBox')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [scriptblock] $ScriptBlock
    )

    try {
        $TextBox = [System.Windows.Controls.TextBox] @{
            Name = $Name
        }
        Register-WPFObject $Name $TextBox
        if ($ScriptBlock) {
            Update-WPFObject $TextBox $ScriptBlock
        }
        Set-WPFObjectType $TextBox 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (TextBox) with error: $_"
    }

    return $TextBox
}
