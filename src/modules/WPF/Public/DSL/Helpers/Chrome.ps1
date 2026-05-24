<#
.SYNOPSIS
    Defines a simplified chrome template for supported styled controls.

.DESCRIPTION
    Chrome is an opt-in style helper that generates a control template shell with
    a named Border part and a ContentPresenter. This hides common template
    boilerplate for controls where rounded chrome styling is frequently needed.

    MVP support is intentionally narrow: Button styles only.

.EXAMPLE
    Style 'PrimaryButton' Button {
        Setter Background '#0A84FF'
        Setter Foreground '#FFFFFF'
        Setter Padding '14,8,14,8'

        Chrome {
            Setter CornerRadius 6
            Setter BorderBrush '#086FD5'
            Setter BorderThickness 2
        }

        Trigger IsEnabled $false -Scope Chrome {
            Setter BorderBrush '#9FC5EF'
            Setter Background '#B6D7FF'
        }
    }
#>
function Chrome {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [scriptblock] $ScriptBlock
    )

    $style = $PSCmdlet.GetVariableValue('this')
    if (-not ($style -is [System.Windows.Style])) {
        Write-Error 'Chrome: Must be used directly inside a Style block.'
        return
    }

    if (-not $style.TargetType) {
        Write-Error 'Chrome: Current Style has no TargetType.'
        return
    }

    if (-not [System.Windows.Controls.Button].IsAssignableFrom($style.TargetType)) {
        Write-Error "Chrome: TargetType '$($style.TargetType.FullName)' is not supported. MVP currently supports Button styles only."
        return
    }

    if ($style.PSObject.Properties['_WPFHasChrome'].Value) {
        Write-Error 'Chrome: A style can only define one Chrome block.'
        return
    }

    $existingTemplateSetter = $style.Setters |
        Where-Object {
            $_ -is [System.Windows.Setter] -and
            $_.Property -eq [System.Windows.Controls.Control]::TemplateProperty
        } |
        Select-Object -First 1

    if ($null -ne $existingTemplateSetter) {
        Write-Error 'Chrome: Cannot be combined with Template in the same style. Choose one.'
        return
    }

    $template = [System.Windows.Controls.ControlTemplate]::new($style.TargetType)

    $chromeFactory = [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.Border])
    $chromeFactory.Name = 'ButtonChrome'

    $styleSetterTable = @{}
    $styleChain = [System.Collections.Generic.List[System.Windows.Style]]::new()
    $currentStyle = $style
    while ($null -ne $currentStyle) {
        $styleChain.Insert(0, $currentStyle)
        $currentStyle = $currentStyle.BasedOn
    }

    foreach ($styleInChain in $styleChain) {
        foreach ($candidateSetter in $styleInChain.Setters) {
            if ($candidateSetter -is [System.Windows.Setter] -and $null -ne $candidateSetter.Property) {
                if ($candidateSetter.Property -eq [System.Windows.Controls.Control]::TemplateProperty) {
                    continue
                }

                $styleSetterTable[$candidateSetter.Property.Name] = $candidateSetter.Value
            }
        }
    }

    if ($styleSetterTable.ContainsKey('Background')) {
        $chromeFactory.SetValue([System.Windows.Controls.Border]::BackgroundProperty, $styleSetterTable['Background'])
    }

    if ($styleSetterTable.ContainsKey('BorderBrush')) {
        $chromeFactory.SetValue([System.Windows.Controls.Border]::BorderBrushProperty, $styleSetterTable['BorderBrush'])
    }

    if ($styleSetterTable.ContainsKey('BorderThickness')) {
        $chromeFactory.SetValue([System.Windows.Controls.Border]::BorderThicknessProperty, $styleSetterTable['BorderThickness'])
    }

    if ($styleSetterTable.ContainsKey('SnapsToDevicePixels')) {
        $chromeFactory.SetValue([System.Windows.UIElement]::SnapsToDevicePixelsProperty, $styleSetterTable['SnapsToDevicePixels'])
    }

    $chromeVars = New-WPFVariableList -InputObject $chromeFactory
    $ScriptBlock.InvokeWithContext($null, $chromeVars) | Out-Null

    $contentPresenterFactory = [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.ContentPresenter])

    if ($styleSetterTable.ContainsKey('Padding')) {
        $contentPresenterFactory.SetValue([System.Windows.FrameworkElement]::MarginProperty, $styleSetterTable['Padding'])
    }

    if ($styleSetterTable.ContainsKey('HorizontalContentAlignment')) {
        $contentPresenterFactory.SetValue([System.Windows.FrameworkElement]::HorizontalAlignmentProperty, $styleSetterTable['HorizontalContentAlignment'])
    } else {
        $contentPresenterFactory.SetValue([System.Windows.FrameworkElement]::HorizontalAlignmentProperty, [System.Windows.HorizontalAlignment]::Center)
    }

    if ($styleSetterTable.ContainsKey('VerticalContentAlignment')) {
        $contentPresenterFactory.SetValue([System.Windows.FrameworkElement]::VerticalAlignmentProperty, $styleSetterTable['VerticalContentAlignment'])
    } else {
        $contentPresenterFactory.SetValue([System.Windows.FrameworkElement]::VerticalAlignmentProperty, [System.Windows.VerticalAlignment]::Center)
    }

    $contentPresenterFactory.SetValue([System.Windows.Controls.ContentPresenter]::RecognizesAccessKeyProperty, $true)

    $chromeFactory.AppendChild($contentPresenterFactory)
    $template.VisualTree = $chromeFactory

    $style.Setters.Add(
        [System.Windows.Setter]::new(
            [System.Windows.Controls.Control]::TemplateProperty,
            $template
        )
    ) | Out-Null

    $style | Add-Member -NotePropertyName '_WPFHasChrome' -NotePropertyValue $true -Force
    $style | Add-Member -NotePropertyName '_WPFChromeTemplate' -NotePropertyValue $template -Force
    $style | Add-Member -NotePropertyName '_WPFChromeTargetName' -NotePropertyValue 'ButtonChrome' -Force
    $style | Add-Member -NotePropertyName '_WPFChromeTargetType' -NotePropertyValue ([System.Windows.Controls.Border]) -Force
}
