<#
.SYNOPSIS
    Adds a linear gradient brush resource entry to the current theme dictionary.

.DESCRIPTION
    Creates a LinearGradientBrush and optionally configures it inside a trailing
    script block.

    When called inside Theme, the brush is stored under a key on the current
    Theme dictionary. In other contexts, the configured brush object is returned
    so it can be assigned directly to properties like Fill.

    Use `$this` to set brush properties directly. Method calls are available
    only when the WPF API requires them, such as adding gradient stops.

.EXAMPLE
    Theme 'Accent' {
        LinearGradientBrush 'WindowBackground' {
            $this.StartPoint = '0,0'
            $this.EndPoint = '1,0'
            GradientStop '#FF0A84FF' 0
            GradientStop '#FF086FD5' 1
        }
    }

.EXAMPLE
    Rectangle 'BannerFill' {
        $this.Fill = LinearGradientBrush {
            $this.StartPoint = '0,0'
            $this.EndPoint = '1,1'
            GradientStop 'Yellow' 0.0
            GradientStop 'Red' 0.25
            GradientStop 'Blue' 0.75
            GradientStop 'LimeGreen' 1.0
        }
    }
#>
function LinearGradientBrush {
    [CmdletBinding()]
    [OutputType([void], [System.Windows.Media.LinearGradientBrush])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Keyed', Position = 0)]
        [ValidateScript({ $_ -isnot [scriptblock] })]
        [ValidateNotNullOrEmpty()]
        [string] $Key,

        [Parameter(Mandatory, ParameterSetName = 'Keyed', Position = 1)]
        [Parameter(Mandatory, ParameterSetName = 'ScriptBlockOnly', Position = 0)]
        [scriptblock] $ScriptBlock
    )

    $brush = [System.Windows.Media.LinearGradientBrush]::new()

    if ($null -ne $ScriptBlock) {
        $PSVars = New-WPFVariableList -InputObject $brush
        $ScriptBlock.InvokeWithContext($null, $PSVars, @()) | Out-Null
    }

    $dictionary = $PSCmdlet.GetVariableValue('this')
    if ($dictionary -is [System.Windows.ResourceDictionary]) {
        if ($PSCmdlet.ParameterSetName -ne 'Keyed') {
            Write-Error 'LinearGradientBrush inside Theme requires a resource key.'
            return
        }

        $dictionary[$Key] = $brush
        return
    }

    if ($PSCmdlet.ParameterSetName -eq 'Keyed') {
        Write-Error "LinearGradientBrush key '$Key' is only valid inside Theme. Use the scriptblock-only form when assigning to properties such as Fill."
        return
    }

    return $brush
}
