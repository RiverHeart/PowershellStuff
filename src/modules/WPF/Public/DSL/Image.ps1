<#
.SYNOPSIS
    Creates a WPF Image object.

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -Image 'MyImage' { ...code... }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.controls.image
#>
function Image {
    [CmdletBinding()]
    [Alias('-Image')]
    [OutputType([void], [System.Windows.Controls.Image])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\w+$')]
        [string] $Name,

        [scriptblock] $ScriptBlock
    )

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Name
        return
    }

    try {
        $Image = [System.Windows.Controls.Image] @{
            Name = $Name
        }
        Register-WPFObject $Name $Image
        Add-WPFType $Image 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Image) with error: $_"
    }

    # Auto-attach self to parent if one exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    $IsParentedBefore = [bool] $Image.Parent
    if ($Parent -and -not $IsParentedBefore) {
        Write-Debug "Beginning auto-attach for $Name (Image)"
        Update-WPFObject $Parent $Image
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (Image)"
    Update-WPFObject $Image $ScriptBlock

    $IsParentedAfter = [bool] $Image.Parent
    $IsCollectingChildren = [bool] $PSCmdlet.GetVariableValue('WPFCollectChildren')
    if ($IsCollectingChildren -or -not $IsParentedAfter) {
        return $Image
    }
}
