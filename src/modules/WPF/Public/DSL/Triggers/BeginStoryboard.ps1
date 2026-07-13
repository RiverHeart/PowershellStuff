<#
.SYNOPSIS
    Adds a BeginStoryboard action to the current EventTrigger.

.DESCRIPTION
    Creates a System.Windows.Media.Animation.BeginStoryboard and appends it to
    the current EventTrigger actions collection.

    The optional scriptblock runs with `$this` bound to the created
    BeginStoryboard so Storyboard can assign animation content.

.EXAMPLE
    EventTrigger 'Mouse.MouseEnter' {
        BeginStoryboard 'HoverStoryboard' {
            Storyboard {
                DoubleAnimation -Target 'GlassCube' -Property '(UIElement.Opacity)' -To 1 -Duration '0:0:0.2'
            }
        }
    }
#>
function BeginStoryboard {
    [CmdletBinding(DefaultParameterSetName = 'NoName')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Named')]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Position = 1, ParameterSetName = 'Named')]
        [Parameter(Position = 0, ParameterSetName = 'NoName')]
        [scriptblock] $ScriptBlock,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        $context = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }
        if (-not ($context -is [System.Windows.EventTrigger])) {
            Write-Error 'BeginStoryboard: Must be used inside an EventTrigger block.'
            return
        }

        $action = [System.Windows.Media.Animation.BeginStoryboard]::new()

        if ($PSBoundParameters.ContainsKey('Name')) {
            $action.Name = $Name

            $triggerHostProperty = $context.PSObject.Properties['_WPFTriggerHost']
            $triggerHost = if ($triggerHostProperty) { $triggerHostProperty.Value } else { $null }

            if ($null -ne $triggerHost) {
                try {
                    $triggerHost.RegisterName($Name, $action)
                } catch {
                    Write-Error "BeginStoryboard: Failed to register name '$Name' in trigger host scope. $($_.Exception.Message)"
                    return
                }
            }
        }

        if ($ScriptBlock) {
            $PSVars = New-WPFVariableList -InputObject $action
            $null = $ScriptBlock.InvokeWithContext($null, $PSVars, @())
        }

        $context.Actions.Add($action) | Out-Null
    }
}
