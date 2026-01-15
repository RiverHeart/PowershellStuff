<#
.SYNOPSIS
    Creates a WPF TextBox object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.textbox
#>
function New-WPFTextBox {
    [Alias('TextBox')]
    [OutputType([System.Windows.Controls.TextBox])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [scriptblock] $ScriptBlock
    )

    try {
        $WPFObject = [System.Windows.Controls.TextBox] @{
            Name = $Name
        }
        Register-WPFObject $Name $WPFObject
        Add-WPFType $WPFObject 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (TextBox) with error: $_"
    }

    if ($ScriptBlock) {
        # NOTE: Allow exceptions from child objects to bubble up
        Update-WPFObject $WPFObject $ScriptBlock
    }

    return $WPFObject
}
