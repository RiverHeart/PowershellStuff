<#
.SYNOPSIS
    Creates a WPF Image object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.image
#>
function New-WPFImage {
    [CmdletBinding()]
    [Alias('Image')]
    [OutputType([System.Windows.Controls.Image])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [scriptblock] $ScriptBlock
    )

    $WPFObject = [System.Windows.Controls.Image] @{
        Name = $Name
    }
    Register-WPFObject $Name $WPFObject
    if ($ScriptBlock) {
        Update-WPFObject $WPFObject $ScriptBlock
    }
    Add-WPFType $WPFObject 'Control'

    return $WPFObject
}
