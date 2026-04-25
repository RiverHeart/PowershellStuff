function Button {
    [CmdletBinding()]
    [OutputType([void], [System.Windows.Controls.Button])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^\w+$')]
        [string] $Name,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    try {
        $Button = [System.Windows.Controls.Button] @{
            Name = $Name
        }
        Register-WPFObject $Name $Button
        Add-WPFType $Button 'Control'
    } catch {
        Write-Error "Failed to create '$Name' (Button) with error: $_"
    }

    # Auto-attach if parent exists
    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($Parent) {
        Write-Debug "Beginning auto-attach for $Name (Button)"
        Update-WPFObject $Parent $Button
    }

    # NOTE: Allow exceptions from child objects to bubble up
    Write-Debug "Processing child elements for $Name (Button)"
    Update-WPFObject $Button $ScriptBlock

    if ($this.Parent) { return }
    return $Button
}
