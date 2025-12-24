
function New-WPFDatePicker {
    [Alias('DatePicker')]
    [OutputType([System.Windows.Controls.DatePicker])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    $DatePicker = [System.Windows.Controls.DatePicker]::new()
    $DatePicker.Name = $Name
    Update-WPFObject $DatePicker $ScriptBlock
    Set-WPFObjectType $DatePicker 'Control'
    return $DatePicker
}
