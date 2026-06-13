<#
.SYNOPSIS
    Creates a WPF Window object.

.DESCRIPTION
    Creates a WPF Window object. Window is always treated as a root element
    and will never auto-attach to a parent. Use the Owner property to establish
    an owner relationship for modal dialogs.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -Window 'MainWindow' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.window
#>
function Window {
    [CmdletBinding()]
    [Alias('-Window')]
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

        if (-not $Window.Height -and -not $Window.Width){
            $Window.SizeToContent = 'WidthAndHeight'
        }
        Add-WPFType $Window 'Control'
    } catch {
        Remove-WPFControlContext -ContextId $ContextId
        Write-Error "Failed to create '$Name' (Window) with error: $_"
    }

    # Window is always root; do not auto-attach to parent
    # Use the Owner property to establish ownership relationships

    $ShouldAutoClose = $false
    $EffectiveAutoCloseSeconds = 0.0
    $CallerBoundParameters = $PSCmdlet.GetVariableValue('PSBoundParameters', $null)
    $CallerAutoCloseSeconds = $PSCmdlet.GetVariableValue('AutoCloseSeconds', $null)

    # Prefer explicit caller AutoCloseSeconds. Fallback to WPF_AUTO_CLOSE_SECONDS.
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

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (Window)"
    Update-WPFObject $Window $ScriptBlock

    return $Window
}
