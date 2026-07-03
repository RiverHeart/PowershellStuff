<#
.SYNOPSIS
    Creates a WPF StatusBar object.

.DESCRIPTION
    Supports both named and nameless forms:

    StatusBar 'Footer' { ... }
    StatusBar { ... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.primitives.statusbar
#>
function StatusBar {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-StatusBar')]
    [OutputType([void], [System.Windows.Controls.Primitives.StatusBar])]
    param(
        [Parameter(ParameterSetName = 'Name', Position = 0)]
        [ValidateScript({ $_ -isnot [scriptblock] })]
        [ValidatePattern('^\w+$')]
        [string] $Name = '__Nameless__',

        [Parameter(Mandatory, ParameterSetName = 'Name', Position = 1)]
        [Parameter(Mandatory, ParameterSetName = 'ScriptBlock', Position = 0)]
        [scriptblock] $ScriptBlock
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

    try {
        $StatusBar = [System.Windows.Controls.Primitives.StatusBar]::new()
        if ($Name -ne '__Nameless__') {
            $StatusBar.Name = $Name
            Register-WPFObject $Name $StatusBar
        }
        Add-WPFType $StatusBar 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (StatusBar) with error: $_"
    }

    $Parent = $PSCmdlet.GetVariableValue('this')
    $WasAutoAttached = $false
    if ($Parent -and -not $StatusBar.Parent) {
        $AppRootProperty = $Parent.PSObject.Properties['_WPFAppRoot']
        $AppContentProperty = $Parent.PSObject.Properties['_WPFAppContent']

        $IsAppWindow =
            $Parent -is [System.Windows.Window] -and
            $AppRootProperty -and
            $AppRootProperty.Value -and
            $AppContentProperty -and $AppContentProperty.Value

        if ($IsAppWindow) {
            Write-Debug "Beginning app-statusbar auto-attach for $Name (StatusBar)"
            Add-WPFAppRootChild -Window $Parent -Child $StatusBar -Placement 'StatusBar'
            $WasAutoAttached = $true
        } else {
            Write-Debug "Beginning auto-attach for $Name (StatusBar)"
            Add-WPFObject $Parent $StatusBar
            $WasAutoAttached = $true
        }
    }

    Write-Debug "Processing child elements for $Name (StatusBar)"
    Update-WPFObject $StatusBar $ScriptBlock

    if (-not $WasAutoAttached) {
        return $StatusBar
    }
}
