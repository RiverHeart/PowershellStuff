<#
.SYNOPSIS
    Creates a WPF StackPanel object.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -StackPanel 'MyPanel' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.stackpanel
#>
function StackPanel {
    [CmdletBinding()]
    [Alias('-StackPanel', 'VStackPanel', 'HStackPanel')]
    [OutputType([void], [System.Windows.Controls.StackPanel])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\w+$')]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    # Change behavior based on invocation name.
    switch ($MyInvocation.InvocationName) {
        '-StackPanel' {
            Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
            return
        }
        'VStackPanel' { $Orientation = [System.Windows.Controls.Orientation]::Vertical }
        'HStackPanel' { $Orientation = [System.Windows.Controls.Orientation]::Horizontal }
        default { $Orientation = [System.Windows.Controls.Orientation]::Vertical }
    }

    try {
        $StackPanel = [System.Windows.Controls.StackPanel] @{
            Name = $Name
            Orientation = $Orientation
        }
        Register-WPFObject $Name $StackPanel
        Add-WPFType $StackPanel 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (StackPanel) with error: $_"
    }

    # Attach to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $StackPanel.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (StackPanel)"
        Update-WPFObject $Parent $StackPanel
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (StackPanel)"
    Update-WPFObject $StackPanel $ScriptBlock

    $IsParentedAfter = [bool] $StackPanel.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $StackPanel
    }
}
