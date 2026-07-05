<#!
.SYNOPSIS
    Creates a TemplateBindingExtension for the current template context.

.DESCRIPTION
    Resolves a dependency property against the templated control type and
    returns a System.Windows.TemplateBindingExtension that can be used in
    template factory setter shorthand.

    Intended usage:

        Background: (TemplateBinding Background)
        Content: (TemplateBinding Content)

.EXAMPLE
    Template {
        Border 'TemplateBorder' {
            Background: (TemplateBinding Background)
        }
    }
#>
function TemplateBinding {
    [CmdletBinding()]
    [OutputType([System.Windows.TemplateBindingExtension])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Property
    )

    $templateTargetType = $PSCmdlet.GetVariableValue('WPFTemplateTargetType')
    if (-not ($templateTargetType -is [Type])) {
        foreach ($scopeIndex in 1..5) {
            $templateTargetType = Get-Variable -Name 'WPFTemplateTargetType' -Scope $scopeIndex -ValueOnly -ErrorAction SilentlyContinue
            if ($templateTargetType -is [Type]) {
                break
            }
        }
    }

    if (-not ($templateTargetType -is [Type])) {
        Write-Error 'TemplateBinding: Must be used inside a Template context.'
        return
    }

    $resolvedProperty = Resolve-WPFDependencyProperty -Property $Property -TargetType $templateTargetType
    if (-not $resolvedProperty) {
        Write-Error "TemplateBinding: Property '$Property' is not a dependency property on type '$($templateTargetType.FullName)'."
        return
    }

    return [System.Windows.TemplateBindingExtension]::new($resolvedProperty.DependencyProperty)
}
