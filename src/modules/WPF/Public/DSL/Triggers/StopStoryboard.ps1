<#
.SYNOPSIS
    Adds a StopStoryboard action to the current EventTrigger.

.DESCRIPTION
    Creates a System.Windows.Media.Animation.StopStoryboard and appends it to
    the current EventTrigger actions collection.

.EXAMPLE
    EventTrigger 'Mouse.MouseLeave' {
        StopStoryboard 'HoverStoryboard'
    }
#>
function StopStoryboard {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('BeginStoryboardName')]
        [string] $Name,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        $context = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }
        if (-not ($context -is [System.Windows.EventTrigger])) {
            Write-Error 'StopStoryboard: Must be used inside an EventTrigger block.'
            return
        }

        $action = [System.Windows.Media.Animation.StopStoryboard]::new()
        $action.BeginStoryboardName = $Name

        $context.Actions.Add($action) | Out-Null
    }
}
