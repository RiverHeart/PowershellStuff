
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
        # Using object because you're probably going to pass a string
        # or int instead of [GridLength] and we need Powershell to recognize
        # the value to resolve the parameter set.
        [Parameter(ParameterSetName='Explicit',Position=0)]
        [object] $Width = [System.Windows.GridLength]::Auto,

        [Parameter(Mandatory,ParameterSetName='Explicit',Position=1)]
        [Parameter(Mandatory,ParameterSetName='Implicit',Position=0)]
        [ScriptBlock] $ScriptBlock
    )

    # Allow for more intuitive GridLength names
    if ($Width -eq 'Expand') {
        # Allow 'Expand*2' syntax
        $Width = $Width -replace 'Expand', '*'
    } elseif ($Width -eq 'Fit') {
        $Width = [System.Windows.GridLength]::Auto
    }

    try {
        $WPFObject = [System.Windows.Controls.ColumnDefinition] @{
            Width = $Width
        }
        Add-WPFType $WPFObject 'GridDefinition'

        $Children = Update-WPFObject $WPFObject $ScriptBlock -PassThru
        $WPFObject | Add-Member -MemberType NoteProperty -Name Children -Value $Children

    } catch {
        Write-Error "Failed to create (ColumnDefinition) with error: $_"
    }
    return $WPFObject
}
