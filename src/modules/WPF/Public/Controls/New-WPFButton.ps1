<#
.SYNOPSIS
    Creates a WPF Button object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.button
#>
function New-WPFButton {
    [Alias('Button')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    try {
        $Button = [System.Windows.Controls.Button] @{
            Name = $Name
            Content = $Content
        }
        Register-WPFObject $Name $Button
        if ($ScriptBlock) {
            Update-WPFObject $Button $ScriptBlock
        }
        Add-WPFType $Button 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Button) with error: $_"
    }

    return $Button
}
