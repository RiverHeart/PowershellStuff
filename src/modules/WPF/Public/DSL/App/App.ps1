<#
.SYNOPSIS
    Creates an application-oriented WPF Window shell.

.DESCRIPTION
    App is a thin wrapper around Window that pre-wires a DockPanel root, a
    constrained content host, an optional footer host, and an implicit
    top-level Menu.

.EXAMPLE
    App 'Example' {
        $this.Title = 'Example'
        MenuItem 'File/Open' { }
    }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.window
#>
function App {
    [CmdletBinding()]
    [Alias('-App')]
    [OutputType([void], [System.Windows.Window])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\w+$')]
        [string] $Name,

        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

    $ContextId = New-WPFControlContext -Name $Name -Activate

    try {
        $Window = [System.Windows.Window] @{
            Name = $Name
        }
        Set-WPFControlContext -InputObject $Window -ContextId $ContextId
        Register-WPFObject -Name $Name -InputObject $Window -ContextId $ContextId -Overwrite
        Register-WPFObject -Name '__WPFWindow' -InputObject $Window -ContextId $ContextId -Overwrite
        $Window.Resources['WPFDialogCloseReason'] = 'User'

        $Window.Add_Closed({
            param($Sender, $Args)
            Remove-WPFControlContext -InputObject $Sender
        })

        if (-not $Window.Height -and -not $Window.Width) {
            $Window.SizeToContent = 'WidthAndHeight'
        }
        Add-WPFType $Window 'Control'

        $Root = [System.Windows.Controls.DockPanel]::new()
        $Window.Content = $Root
        $Window | Add-Member -NotePropertyName '_WPFAppRoot' -NotePropertyValue $Root -Force

        # Use a Grid content host so body controls are measured with finite space.
        # This avoids unbounded StackPanel measurement issues for viewport controls
        # like ScrollViewer, DataGrid, and image surfaces.
        $Content = [System.Windows.Controls.Grid] @{
            Name = "${Name}Content"
            Margin = 5
        }
        Register-WPFObject -Name $Content.Name -InputObject $Content -ContextId $ContextId
        Add-WPFType $Content 'Control'
        $Window | Add-Member -NotePropertyName '_WPFAppContent' -NotePropertyValue $Content -Force
        Add-WPFAppRootChild -Window $Window -Child $Content -Placement 'Content'
    } catch {
        Remove-WPFControlContext -ContextId $ContextId
        Write-Error "Failed to create '$Name' (App) with error: $_"
    }

    $ShouldAutoClose = $false
    $EffectiveAutoCloseSeconds = 0.0
    $CallerBoundParameters = $PSCmdlet.GetVariableValue('PSBoundParameters', $null)
    $CallerAutoCloseSeconds = $PSCmdlet.GetVariableValue('AutoCloseSeconds', $null)

    if ($CallerBoundParameters -and
        ($CallerBoundParameters -is [System.Collections.IDictionary]) -and
        $CallerBoundParameters.ContainsKey('AutoCloseSeconds')
    ) {
        $ShouldAutoClose = $true
        $EffectiveAutoCloseSeconds = [double] $CallerAutoCloseSeconds
    } else {
        $EnvironmentAutoCloseSeconds = Get-WPFEnvironmentAutoCloseSeconds
        if ($null -ne $EnvironmentAutoCloseSeconds) {
            $ShouldAutoClose = $true
            $EffectiveAutoCloseSeconds = [double] $EnvironmentAutoCloseSeconds
        }
    }

    if ($ShouldAutoClose) {
        Enable-WPFAutoClose -Window $Window -AutoCloseSeconds ([double] $EffectiveAutoCloseSeconds)
    }

    Write-Debug "Processing child elements for $Name (App)"
    Update-WPFObject $Window $ScriptBlock

    return $Window
}
