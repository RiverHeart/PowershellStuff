using namespace System.Collections.Generic
using namespace System.Windows.Input

<#
.SYNOPSIS
    Converts one or more key gesture strings into WPF KeyGesture objects.

.DESCRIPTION
    Converts gesture strings such as 'Ctrl+Shift+S' into
    [System.Windows.Input.KeyGesture] objects.

    This helper centralizes conversion so DSL keywords such as Command and Key
    can share consistent parsing and error handling.

.EXAMPLE
    ConvertTo-KeyGesture -InputObject 'Ctrl+Shift+S'

.EXAMPLE
    ConvertTo-KeyGesture -InputObject @('Ctrl+S', 'F11')
#>
function ConvertTo-KeyGesture {
    [CmdletBinding()]
    [OutputType([KeyGesture[]])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string[]] $InputObject
    )

    begin {
        $Converter = [KeyGestureConverter]::new()
        $ParsedGestures = [List[KeyGesture]]::new()
    }

    process {
        foreach ($GestureText in $InputObject) {
            try {
                $ParsedGesture = $Converter.ConvertFromString($GestureText)
            } catch {
                throw "Invalid key gesture '$GestureText'. $($_.Exception.Message)"
            }

            if ($ParsedGesture -isnot [KeyGesture]) {
                throw "Invalid key gesture '$GestureText'."
            }

            [void] $ParsedGestures.Add([KeyGesture] $ParsedGesture)
        }
    }

    end {
        return $ParsedGestures.ToArray()
    }
}
