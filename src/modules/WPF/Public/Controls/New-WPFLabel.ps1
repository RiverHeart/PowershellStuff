function New-WPFLabel {
    [Alias('Label')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    try {
        $Label = [System.Windows.Controls.Label] @{
            Name = $Name
        }
        Register-WPFObject $Name $Label
        if ($ScriptBlock) {
            Update-WPFObject $Label $ScriptBlock
        }
        Set-WPFObjectType $Label 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Label) with error: $_"
    }

    return $Label
}
