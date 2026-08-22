<#
.SYNOPSIS
    Creates a WPF ComboBox object.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -ComboBox 'MyComboBox' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.combobox
#>
function ComboBox {
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('-ComboBox')]
    [OutputType([void], [System.Windows.Controls.ComboBox])]
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
        $ComboBox = [System.Windows.Controls.ComboBox]::new()
        if ($Name -ne '__Nameless__') {
            $ComboBox.Name = $Name
            Register-WPFObject $Name $ComboBox
        }
        Add-WPFType $ComboBox 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (ComboBox) with error: $_"
    }

    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $ComboBox.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (ComboBox)"
        Update-WPFObject $Parent $ComboBox
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (ComboBox)"
    Update-WPFObject $ComboBox $ScriptBlock

    $IsParentedAfter = [bool] $ComboBox.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $ComboBox
    }
}
