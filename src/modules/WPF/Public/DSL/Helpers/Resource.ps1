<#
.SYNOPSIS
    Binds a dependency property to a WPF resource key using DynamicResource.

.DESCRIPTION
    In WPF, a resource is an entry in a ResourceDictionary, such as a Brush,
    Style, or other shared object identified by key.

    The `Resource` keyword resolves a dependency property by name on the
    current target and calls SetResourceReference so the property consumes
    that keyed value and updates when the active resource dictionary changes.

.NOTES
    Use this when you want a control property, such as Background or Foreground,
    to track a theme resource instead of a fixed value.

    If you only need a brush or object inside one script, a PowerShell variable
    is usually simpler. Use a WPF resource when the value should be named in the
    UI, shared across controls, or updated by theme switching.

.EXAMPLE
    Theme 'Light' {
        Brush 'WindowBackground' '#FFFFFF'
    }

    Window 'Main' {
        Resource WindowBackground Background
    }

.NOTES
    This keyword does not create the resource itself. Define the resource in a
    Theme or ResourceDictionary, then use Resource to consume it from a control
    or style target.
#>
function Resource {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNull()]
        [object] $Key,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $Property,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        $target = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }
        if (-not $target) {
            Write-Error "Resource: Unable to resolve target object for property '$Property'."
            return
        }

        if ($Key -is [string] -and [string]::IsNullOrWhiteSpace($Key)) {
            Write-Error "Resource: Resource key for property '$Property' cannot be empty."
            return
        }

        $type = $target.GetType()
        $resolvedProperty = Resolve-WPFDependencyProperty -Property $Property -TargetType $type

        if (-not $resolvedProperty) {
            Write-Error "Resource: Property '$Property' is not a dependency property on type '$($type.FullName)'."
            return
        }

        $target.SetResourceReference($resolvedProperty.DependencyProperty, $Key)
    }
}
