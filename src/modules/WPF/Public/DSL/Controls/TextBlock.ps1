<#
.SYNOPSIS
    Creates a WPF TextBlock object.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -TextBlock 'MyText' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.textblock
#>
function TextBlock {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-TextBlock')]
    [OutputType([void], [System.Windows.Controls.TextBlock])]
    param(
        [Parameter(ParameterSetName = 'Name', Position = 0)]
        [ValidateScript({ $_ -isnot [scriptblock] })]
        [ValidatePattern('^\w+$')]
        [string] $Name = '__Nameless__',

        [Parameter(Mandatory, ParameterSetName = 'Name', Position = 1)]
        [Parameter(Mandatory, ParameterSetName = 'ScriptBlock', Position = 0)]
        [ScriptBlock] $ScriptBlock,

        [System.Windows.FrameworkElement] $AutoAttach,
        [switch] $Factory
    )

    $TypeName = 'TextBlock'

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

    # Factory mode: inside a Template/HierarchicalItemTemplate block, produce a
    # FrameworkElementFactory instead of a live TextBlock instance.
    $CreateFactory =
        if ($Factory) { $Factory }
        else { $PSCmdlet.GetVariableValue('WPFFactoryContext') -eq $true }

    if ($CreateFactory) {
        $TypeName = "$TypeName Factory"
        Write-Debug "Creating $Name ($TypeName)"
        if ($Name -ne '__Nameless__') {
            $OutputObject = [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.TextBlock], $Name)
        } else {
            $OutputObject = [System.Windows.FrameworkElementFactory]::new([System.Windows.Controls.TextBlock])
        }
    } else {
        Write-Debug "Creating $Name ($TypeName)"
        try {
            $OutputObject = [System.Windows.Controls.TextBlock]::new()
            if ($Name -ne '__Nameless__') {
                $OutputObject.Name = $Name
                Register-WPFObject $Name $OutputObject
            }
            Add-WPFType $OutputObject 'Control'
        } catch {
            Write-Error "Failed to create '$Name' ($TypeName) with error: $_"
        }
    }

    # Attach to parent if one exists
    $Parent = Resolve-WPFAutoAttachTarget `
        -Cmdlet $PSCmdlet `
        -BoundParameters $PSBoundParameters `
        -AutoAttach $AutoAttach

    $AlreadyParented = [bool] $OutputObject.Parent
    if ($Parent -and -not $AlreadyParented) {
        Write-Debug "Auto-attaching $Name ($TypeName) to $($Parent.Name) ($($Parent.GetType().Name))"
        Update-WPFObject $Parent $OutputObject
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name ($TypeName)"
    Update-WPFObject $OutputObject $ScriptBlock

    $BecameParented = [bool] $OutputObject.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $BecameParented) {
        return $OutputObject
    }
}
