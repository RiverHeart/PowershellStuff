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
    [CmdletBinding()]
    [Alias('-TextBlock')]
    [OutputType([void], [System.Windows.Controls.TextBlock])]
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
        $TextBlock = [System.Windows.Controls.TextBlock] @{
            Name = $Name
        }
        Register-WPFObject $Name $TextBlock
        Add-WPFType $TextBlock 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (TextBlock) with error: $_"
    }

    # Attach to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($Parent) {
        Write-Debug "Beginning auto-attach for $Name (TextBlock)"
        Update-WPFObject $Parent $TextBlock
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (TextBlock)"
    Update-WPFObject $TextBlock $ScriptBlock

    if ($this.Parent) { return }
    return $TextBlock
}
