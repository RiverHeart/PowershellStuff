<#
.SYNOPSIS
    Creates a WPF DatePicker object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.datepicker
#>
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

    try {
        $DatePicker = [System.Windows.Controls.DatePicker] @{
            Name = $Name
        }
        Register-WPFObject $Name $DatePicker
        if ($ScriptBlock) {
            Update-WPFObject $DatePicker $ScriptBlock
        }
        Set-WPFObjectType $DatePicker 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (DatePicker) with error: $_"
    }
    return $DatePicker
}
