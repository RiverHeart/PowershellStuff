
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
        # Using object because you're probably going to pass a string
        # or int instead of [GridLength] and we need Powershell to recognize
        # the value to resolve the parameter set.
        [Parameter(ParameterSetName='Explicit',Position=0)]
        [object] $Height = [System.Windows.GridLength]::Auto,

        [Parameter(Mandatory,ParameterSetName='Explicit',Position=1)]
        [Parameter(Mandatory,ParameterSetName='Implicit',Position=0)]
        [ScriptBlock] $ScriptBlock
    )

    # Allow for more intuitive GridLength names
    if ($Height -eq 'Expand') {
        # Allow 'Expand*2' syntax
        $Height = $Height -replace 'Expand', '*'
    } elseif ($Height -eq 'Fit') {
        $Height = [System.Windows.GridLength]::Auto
    }

    try {
        $WPFObject = [System.Windows.Controls.RowDefinition] @{
            Height = $Height
        }
        Add-WPFType $WPFObject 'GridDefinition'

        $Children = Update-WPFObject $WPFObject $ScriptBlock -PassThru
        $WPFObject | Add-Member -MemberType NoteProperty -Name Children -Value $Children
    } catch {
        Write-Error "Failed to create '(RowDefinition) with error: $_"
    }
    return $WPFObject
}
