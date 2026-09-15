<#
.SYNOPSIS
    Creates a WPF Expander object.

.EXAMPLE
    Creates an Expander containing a StackPanel.

    Expander 'Details' {
        $this.Header = 'Details'

        StackPanel {
            TextBlock { $this.Text = 'More information' }
        }
    }

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -Expander 'Details' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.expander
#>
function Expander {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-Expander')]
    [OutputType([void], [System.Windows.Controls.Expander])]
    param(
        [Parameter(ParameterSetName = 'Name', Position = 0)]
        [ValidateScript({ $_ -isnot [scriptblock] })]
        [ValidatePattern('^\w+$')]
        [string] $Name = '__Nameless__',

        [Parameter(Mandatory, ParameterSetName = 'Name', Position = 1)]
        [Parameter(Mandatory, ParameterSetName = 'ScriptBlock', Position = 0)]
        [ScriptBlock] $ScriptBlock
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

    try {
        $Expander = [System.Windows.Controls.Expander]::new()
        if ($Name -ne '__Nameless__') {
            $Expander.Name = $Name
            Register-WPFObject $Name $Expander
        }
        Add-WPFType $Expander 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Expander) with error: $_"
    }

    $Parent = $PSCmdlet.GetVariableValue('WPFAutoAttachContext')
    $IsParentedBefore = [bool] $Expander.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (Expander)"
        Update-WPFObject $Parent $Expander
    }

    Write-Debug "Processing child elements for $Name (Expander)"
    Update-WPFObject $Expander $ScriptBlock

    $IsParentedAfter = [bool] $Expander.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $Expander
    }
}
