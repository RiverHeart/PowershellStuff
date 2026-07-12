<#
.SYNOPSIS
    Adds a DoubleAnimation to the current Storyboard.

.DESCRIPTION
    Creates a System.Windows.Media.Animation.DoubleAnimation and appends it to
    the current Storyboard.

    Target name and target property path are optional. When provided, they are
    applied through Storyboard attached properties.

.EXAMPLE
    Storyboard {
        DoubleAnimation -Target 'GlassCube' -Property '(UIElement.Opacity)' -To 1 -Duration '0:0:0.2'
    }
#>
function DoubleAnimation {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter()]
        [double] $From,

        [Parameter()]
        [double] $To,

        [Parameter()]
        [double] $By,

        [Parameter()]
        [Alias('TargetName')]
        [ValidateNotNullOrEmpty()]
        [string] $Target,

        [Parameter()]
        [Alias('Property', 'TargetProperty')]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter()]
        [AllowNull()]
        [object] $Duration,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        $context = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }
        if (-not ($context -is [System.Windows.Media.Animation.Storyboard])) {
            Write-Error 'DoubleAnimation: Must be used inside a Storyboard block.'
            return
        }

        $animation = [System.Windows.Media.Animation.DoubleAnimation]::new()

        if ($PSBoundParameters.ContainsKey('From')) {
            $animation.From = $From
        }

        if ($PSBoundParameters.ContainsKey('To')) {
            $animation.To = $To
        }

        if ($PSBoundParameters.ContainsKey('By')) {
            $animation.By = $By
        }

        if ($PSBoundParameters.ContainsKey('Duration')) {
            $resolvedDuration = $null

            if ($Duration -is [System.Windows.Duration]) {
                $resolvedDuration = $Duration
            } elseif ($Duration -is [TimeSpan]) {
                $resolvedDuration = [System.Windows.Duration]::new($Duration)
            } elseif ($Duration -is [string]) {
                try {
                    $parsedTimeSpan = [TimeSpan]::Parse($Duration, [System.Globalization.CultureInfo]::InvariantCulture)
                    $resolvedDuration = [System.Windows.Duration]::new($parsedTimeSpan)
                } catch {
                    Write-Error "DoubleAnimation: Failed to parse Duration '$Duration'. Use a TimeSpan, Duration, or time string such as '0:0:0.5'."
                    return
                }
            } else {
                Write-Error "DoubleAnimation: Unsupported Duration type '$($Duration.GetType().FullName)'."
                return
            }

            $animation.Duration = $resolvedDuration
        }

        if ($PSBoundParameters.ContainsKey('Target')) {
            [System.Windows.Media.Animation.Storyboard]::SetTargetName($animation, $Target)
        }

        if ($PSBoundParameters.ContainsKey('Path')) {
            [System.Windows.Media.Animation.Storyboard]::SetTargetProperty(
                $animation,
                [System.Windows.PropertyPath]::new($Path)
            )
        }

        $context.Children.Add($animation) | Out-Null
    }
}
