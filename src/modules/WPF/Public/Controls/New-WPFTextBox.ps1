<#
.SYNOPSIS
    Creates a WPF TextBox object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.textbox
#>
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
        Add-WPFType $TextBox 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (TextBox) with error: $_"
    }

    return $TextBox
}
