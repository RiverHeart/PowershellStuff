<#
.SYNOPSIS
    Creates a WPF Rectangle shape.

.DESCRIPTION
    Creates a Rectangle shape and processes its trailing script block using the
    standard WPF object pipeline.

    The shape auto-attaches to supported parents such as Button and Border when
    used inside their script blocks.

.EXAMPLE
    Border 'Banner' {
        Rectangle 'BannerFill' {
            $this.Width = 200
            $this.Height = 100
            $this.Fill = LinearGradientBrush {
                $this.StartPoint = '0,0'
                $this.EndPoint = '1,1'
                $this.GradientStops.Add([System.Windows.Media.GradientStop]::new('Yellow', 0.0))
                $this.GradientStops.Add([System.Windows.Media.GradientStop]::new('Red', 0.25))
                $this.GradientStops.Add([System.Windows.Media.GradientStop]::new('Blue', 0.75))
                $this.GradientStops.Add([System.Windows.Media.GradientStop]::new('LimeGreen', 1.0))
            }
        }
    }
#>
function Rectangle {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-Rectangle')]
    [OutputType([void], [System.Windows.Shapes.Rectangle])]
    param(
        [Parameter(ParameterSetName = 'Name', Position = 0)]
        [ValidateScript({ $_ -isnot [scriptblock] })]
        [ValidatePattern('^\w+$')]
        [string] $Name = '__Nameless__',

        [Parameter(Mandatory, ParameterSetName = 'Name', Position = 1)]
        [Parameter(Mandatory, ParameterSetName = 'ScriptBlock', Position = 0)]
        [scriptblock] $ScriptBlock
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

    try {
        $Rectangle = [System.Windows.Shapes.Rectangle]::new()
        if ($Name -ne '__Nameless__') {
            $Rectangle.Name = $Name
            Register-WPFObject $Name $Rectangle
        }
        Add-WPFType $Rectangle 'Shape'
    } catch {
        Write-Error "Failed to create '$Name' (Rectangle) with error: $_"
        return
    }

    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $Rectangle.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (Rectangle)"
        Update-WPFObject $Parent $Rectangle
    }

    Write-Debug "Processing child elements for $Name (Rectangle)"
    Update-WPFObject $Rectangle $ScriptBlock

    $IsParentedAfter = [bool] $Rectangle.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $Rectangle
    }
}
