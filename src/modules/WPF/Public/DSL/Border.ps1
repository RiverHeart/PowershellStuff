<#
.SYNOPSIS
    Creates a WPF Border object.

.DESCRIPTION
    Supports both named and nameless forms:

    Border 'MyBorder' { ... }
    Border { ... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.border
#>
function Border {
    [CmdletBinding()]
    [Alias('-Border')]
    [OutputType([void], [System.Windows.Controls.Border])]
    param(
        [Parameter(Position = 0)]
        [object] $Name,

        [Parameter(Position = 1)]
        [scriptblock] $ScriptBlock
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-Debug "Negative prefix detected. Disabling this block."
        return
    }

    if ($Name -is [scriptblock] -and -not $PSBoundParameters.ContainsKey('ScriptBlock')) {
        $ScriptBlock = $Name
        $Name = $null
    }

    if (-not $ScriptBlock) {
        throw 'Border requires a scriptblock.'
    }

    if ($null -ne $Name) {
        $Name = [string] $Name
        if ([string]::IsNullOrWhiteSpace($Name)) {
            throw 'Border name cannot be empty.'
        }

        if ($Name -notmatch '^\w+$') {
            throw "Invalid Border name '$Name'. Name must match '^\\w+$'."
        }
    }

    try {
        $Border = if ($Name) {
            [System.Windows.Controls.Border] @{
                Name = $Name
            }
        } else {
            [System.Windows.Controls.Border]::new()
        }

        if ($Name) {
            Register-WPFObject $Name $Border
        }

        Add-WPFType $Border 'Control'
    } catch {
        $BorderName = if ($Name) { $Name } else { '__Nameless__' }
        Write-Error "Failed to create '$BorderName' (Border) with error: $_"
    }

    # Auto-attach if parent exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    $WasAutoAttached = $false
    if ($Parent -and -not $Border.Parent) {
        $BorderName = if ($Name) { $Name } else { '__Nameless__' }
        Write-Debug "Beginning auto-attach for $BorderName (Border)"
        Update-WPFObject $Parent $Border
        $WasAutoAttached = $true
    }

    # NOTE: Allow exceptions from child objects to bubble up
    $BorderName = if ($Name) { $Name } else { '__Nameless__' }
    Write-Debug "Processing child elements for $BorderName (Border)"
    Update-WPFObject $Border $ScriptBlock

    if (-not $WasAutoAttached) {
        return $Border
    }
}
