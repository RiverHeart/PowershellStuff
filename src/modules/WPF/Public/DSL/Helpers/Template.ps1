<#
.SYNOPSIS
    Defines a ControlTemplate for the current Style.

.DESCRIPTION
    Creates a ControlTemplate typed to the Style's TargetType and injects a
    factory context so nested control keywords (Border, ContentPresenter, etc.)
    produce FrameworkElementFactory nodes instead of live instances.

    Setter and Trigger work exactly as they do elsewhere in the DSL.

.EXAMPLE
    Style 'MyButton' Button {
        Template {
            Border 'TemplateBorder' {
                Setter Background ButtonBackground -Resource
                Setter CornerRadius 8

                ContentPresenter {
                    Setter HorizontalAlignment ([HorizontalAlignment]::Stretch)
                    Setter VerticalAlignment ([VerticalAlignment]::Stretch)
                }
            }

            Trigger IsMouseOver $true {
                Setter Background ButtonHoverBackground -Resource -Target 'TemplateBorder'
            }
        }
    }
#>
function Template {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [scriptblock] $ScriptBlock
    )

    $style = $PSCmdlet.GetVariableValue('this')
    if (-not ($style -is [System.Windows.Style])) {
        Write-Error 'Template: Must be used directly inside a Style block.'
        return
    }

    if (-not $style.TargetType) {
        Write-Error 'Template: The current Style has no TargetType; cannot create ControlTemplate.'
        return
    }

    $template = [System.Windows.Controls.ControlTemplate]::new($style.TargetType)

    $PSVars = @(
        [psvariable]::new('this', $template)
        [psvariable]::new('WPFFactoryContext', $true)
    )

    $ScriptBlock.InvokeWithContext($null, $PSVars) | Out-Null

    $style.Setters.Add(
        [System.Windows.Setter]::new(
            [System.Windows.Controls.Control]::TemplateProperty,
            $template
        )
    ) | Out-Null
}
