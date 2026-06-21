<#
.SYNOPSIS
    Creates a WPF TextBox object.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -TextBox 'MyText' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.textbox
#>
function TextBox {
    [CmdletBinding()]
    [Alias('-TextBox')]
    [OutputType([void], [System.Windows.Controls.TextBox])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\w+$')]
        [string] $Name,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

    try {
        $TextBox = [System.Windows.Controls.TextBox] @{
            Name = $Name
        }
        Register-WPFObject $Name $TextBox
        Add-WPFType $TextBox 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (TextBox) with error: $_"
    }

    # Attach to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    $HadParentBeforeAttach = [bool] $TextBox.Parent
    if ($Parent -and -not $HadParentBeforeAttach) {
        Write-Debug "Beginning auto-attach for $Name (TextBox)"
        Update-WPFObject $Parent $TextBox
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (TextBox)"
    Update-WPFObject $TextBox $ScriptBlock

    $IsParented = [bool] $TextBox.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')

    if ($IsCollectingChildren -or -not $IsParented) {
        return $TextBox
    }
}
