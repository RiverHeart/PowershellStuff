<#
.SYNOPSIS
    Binds a dependency property to a resource key using DynamicResource.

.DESCRIPTION
    Resolves a dependency property by name on the target object type and calls
    SetResourceReference so values update when the active theme dictionary
    changes.

.EXAMPLE
    Window 'Main' {
        Resource Background WindowBackground
    }
#>
function Resource {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Property,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $Key,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        $target = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }
        if (-not $target) {
            Write-Error "Resource: Unable to resolve target object for property '$Property'."
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
