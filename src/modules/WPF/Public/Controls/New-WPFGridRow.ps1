
<#
.SYNOPSIS
    Creates a WPF RowDefinition object.

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.rowdefinition
#>
function New-WPFGridRow {
    [CmdletBinding(DefaultParameterSetName='Implicit')]
    [Alias('Row', 'New-WPFRowDefinition')]
    [OutputType([System.Windows.Controls.RowDefinition])]
    param(
        [Parameter(ParameterSetName='Explicit',Position=0)]
        [System.Windows.GridLength] $Height = [System.Windows.GridLength]::Auto,

        [Parameter(Mandatory,ParameterSetName='Explicit',Position=1)]
        [Parameter(Mandatory,ParameterSetName='Implicit',Position=0)]
        [ScriptBlock] $ScriptBlock
    )

    try {
        $WPFObject = [System.Windows.Controls.RowDefinition] @{
            Height = $Height
        }
        Set-WPFObjectType $WPFObject 'GridDefinition'

        $Children = Update-WPFObject $WPFObject $ScriptBlock -PassThru
        $WPFObject | Add-Member -MemberType NoteProperty -Name Children -Value $Children
    } catch {
        Write-Error "Failed to create '(RowDefinition) with error: $_"
    }
    return $WPFObject
}
