
<#
.SYNOPSIS
    Creates a WPF ColumnDefinition object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.columndefinition
#>
function New-WPFGridColumn {
    [CmdletBinding(DefaultParameterSetName='Implicit')]
    [Alias('Column', 'Cell', 'New-WPFColumnDefinition')]
    [OutputType([System.Windows.Controls.ColumnDefinition])]
    param(
        [Parameter(ParameterSetName='Explicit',Position=0)]
        [System.Windows.GridLength] $Width = [System.Windows.GridLength]::Auto,

        [Parameter(Mandatory,ParameterSetName='Explicit',Position=1)]
        [Parameter(Mandatory,ParameterSetName='Implicit',Position=0)]
        [ScriptBlock] $ScriptBlock
    )

    try {
        $WPFObject = [System.Windows.Controls.ColumnDefinition] @{
            Width = $Width
        }
        Set-WPFObjectType $WPFObject 'GridDefinition'

        $Children = Update-WPFObject $WPFObject $ScriptBlock -PassThru
        $WPFObject | Add-Member -MemberType NoteProperty -Name Children -Value $Children

    } catch {
        Write-Error "Failed to create (ColumnDefinition) with error: $_"
    }
    return $WPFObject
}
