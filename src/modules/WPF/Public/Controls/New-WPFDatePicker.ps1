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
        $WPFObject = [System.Windows.Controls.DatePicker] @{
            Name = $Name
        }
        Register-WPFObject $Name $WPFObject
        if ($ScriptBlock) {
            Update-WPFObject $WPFObject $ScriptBlock
        }
        Add-WPFType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (DatePicker) with error: $_"
    }
    return $WPFObject
}
