<#
.SYNOPSIS
    Adds a data trigger to a style or control template.

.DESCRIPTION
    Creates a System.Windows.DataTrigger and appends it to the current Style or
    ControlTemplate.

    The trigger binding can be provided as an existing Binding object or as a
    path string. When a path string is used, -Self can be used to bind against
    the current control instance.

    The scriptblock runs with `$this` bound to the created DataTrigger so
    Setter can add triggered values.

.EXAMPLE
    Style 'PrimaryButton' Button {
        DataTrigger 'IsEnabled' $false -Self {
            Setter Opacity 0.4
        }
    }

.EXAMPLE
    $binding = [System.Windows.Data.Binding]::new('IsEnabled')
    $binding.RelativeSource = [System.Windows.Data.RelativeSource]::new([System.Windows.Data.RelativeSourceMode]::TemplatedParent)

    DataTrigger $binding $false {
        Setter Opacity 0.6 -Target 'TemplateBorder'
    }
#>
function DataTrigger {
    [CmdletBinding()]
    [Alias('Add-WPFDataTrigger')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [object] $Binding,

        [Parameter(Mandatory, Position = 1)]
        [AllowNull()]
        [object] $Value,

        [Parameter(Mandatory, Position = 2)]
        [scriptblock] $ScriptBlock,

        [Parameter()]
        [switch] $Self,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        $target = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }
        if (-not $target) {
            Write-Error 'DataTrigger: Unable to resolve current style or template context.'
            return
        }

        if ($target -is [System.Windows.Style]) {
            $targetType = $target.TargetType
            $triggerOwner = 'Style'
        } elseif ($target -is [System.Windows.Controls.ControlTemplate]) {
            $targetType = $target.TargetType
            $triggerOwner = 'ControlTemplate'
        } else {
            Write-Error "DataTrigger: Unsupported target type '$($target.GetType().FullName)'. Use DataTrigger inside Style or ControlTemplate."
            return
        }

        if (-not $targetType) {
            Write-Error 'DataTrigger: Failed to resolve target type for trigger context.'
            return
        }

        if ($Binding -is [string]) {
            if ([string]::IsNullOrWhiteSpace($Binding)) {
                Write-Error 'DataTrigger: Binding path cannot be empty.'
                return
            }

            $resolvedBinding = [System.Windows.Data.Binding]::new($Binding)
            if ($Self) {
                $resolvedBinding.RelativeSource = [System.Windows.Data.RelativeSource]::new([System.Windows.Data.RelativeSourceMode]::Self)
            }
        } elseif ($Binding -is [System.Windows.Data.BindingBase]) {
            if ($Self) {
                Write-Error 'DataTrigger: -Self is only supported when Binding is a path string.'
                return
            }

            $resolvedBinding = $Binding
        } else {
            Write-Error 'DataTrigger: Binding must be a path string or a System.Windows.Data.BindingBase instance.'
            return
        }

        $trigger = [System.Windows.DataTrigger]::new()
        $trigger.Binding = $resolvedBinding
        $trigger.Value = $Value

        $trigger | Add-Member -NotePropertyName '_WPFTriggerTargetType' -NotePropertyValue $targetType -Force
        $trigger | Add-Member -NotePropertyName '_WPFTriggerOwnerType' -NotePropertyValue $triggerOwner -Force

        $PSVars = New-WPFVariableList -InputObject $trigger
        $null = $ScriptBlock.InvokeWithContext($null, $PSVars)

        $target.Triggers.Add($trigger) | Out-Null
    }
}
