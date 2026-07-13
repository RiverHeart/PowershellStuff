<#
.SYNOPSIS
    Evaluates a block against a target's ResourceDictionary.

.DESCRIPTION
    Mirrors XAML-style resource declaration scopes by running the provided
    scriptblock with `$this` bound to a ResourceDictionary.

    The target can be either:
    - A ResourceDictionary directly
    - Any object exposing a writable Resources property (for example Window)

    Inside the block, resource-producing keywords such as Brush,
    LinearGradientBrush, and Style can register entries on the dictionary.

.EXAMPLE
    Window 'Main' {
        Resources {
            LinearGradientBrush 'GrayBlueGradientBrush' {
                $this.StartPoint = '0,0'
                $this.EndPoint = '1,1'
                GradientStop 'DarkGray' 0
                GradientStop '#CCCCFF' 0.5
                GradientStop 'DarkGray' 1
            }

            Style Button {
                Setter Background GrayBlueGradientBrush -Resource
                Setter Width 80
                Setter Margin 10
            }
        }
    }
#>
function Resources {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [scriptblock] $ScriptBlock,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        $target = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }
        if ($null -eq $target) {
            Write-Error 'Resources: Unable to resolve target object.'
            return
        }

        $dictionary = $null
        if ($target -is [System.Windows.ResourceDictionary]) {
            $dictionary = $target
        } else {
            $resourcesProperty = $target.PSObject.Properties['Resources']
            if (-not $resourcesProperty) {
                Write-Error "Resources: Target type '$($target.GetType().FullName)' does not expose a Resources property."
                return
            }

            if ($null -eq $target.Resources) {
                $target.Resources = [System.Windows.ResourceDictionary]::new()
            }

            if (-not ($target.Resources -is [System.Windows.ResourceDictionary])) {
                Write-Error "Resources: Target type '$($target.GetType().FullName)' has a non-ResourceDictionary Resources property."
                return
            }

            $dictionary = $target.Resources
        }

        $PSVars = New-WPFVariableList -InputObject $dictionary
        $null = $ScriptBlock.InvokeWithContext($null, $PSVars, @())
    }
}
