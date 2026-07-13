<#
.SYNOPSIS
    Creates a GradientStopCollection for use with gradient brushes.

.DESCRIPTION
    Creates a System.Windows.Media.GradientStopCollection and optionally
    configures it inside a trailing script block.

    When called inside Theme, the collection is stored under a key on the
    current Theme dictionary. In other contexts, the configured collection is
    returned so it can be assigned directly to brush properties.

.EXAMPLE
    $glassStops = GradientStopCollection {
        GradientStop 'WhiteSmoke' 0.2
        GradientStop 'Transparent' 0.4
        GradientStop 'WhiteSmoke' 0.5
        GradientStop 'Transparent' 0.75
        GradientStop 'WhiteSmoke' 0.9
        GradientStop 'Transparent' 1.0
    }

    $brush = LinearGradientBrush {
        $this.StartPoint = '0,0'
        $this.EndPoint = '1,1'
        $this.GradientStops = $glassStops
    }
#>
function GradientStopCollection {
    [CmdletBinding()]
    [OutputType([void], [System.Windows.Media.GradientStopCollection])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification='Suppressing because the function returns a collection in a single-element array to avoid unwrapping in the pipeline.')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Keyed', Position = 0)]
        [ValidateScript({ $_ -isnot [scriptblock] })]
        [ValidateNotNullOrEmpty()]
        [string] $Key,

        [Parameter(Mandatory, ParameterSetName = 'Keyed', Position = 1)]
        [Parameter(Mandatory, ParameterSetName = 'ScriptBlockOnly', Position = 0)]
        [scriptblock] $ScriptBlock
    )

    $collection = [System.Windows.Media.GradientStopCollection]::new()

    if ($null -ne $ScriptBlock) {
        $PSVars = New-WPFVariableList -InputObject $collection
        # Ignore scriptblock output so this keyword returns only the configured collection.
        $null = $ScriptBlock.InvokeWithContext($null, $PSVars, @())
    }

    $dictionary = $PSCmdlet.GetVariableValue('this')
    if ($dictionary -is [System.Windows.ResourceDictionary]) {
        if ($PSCmdlet.ParameterSetName -ne 'Keyed') {
            Write-Error 'GradientStopCollection inside a Resources/Theme block requires a resource key.'
            return
        }

        $dictionary[$Key] = $collection
        return
    }

    if ($PSCmdlet.ParameterSetName -eq 'Keyed') {
        Write-Error "GradientStopCollection key '$Key' is only valid inside Resources/Theme dictionary scopes. Use the scriptblock-only form when assigning directly to brush properties."
        return
    }

    # Return the collection as a single-element array to avoid unwrapping in the pipeline.
    return ,$collection
}
