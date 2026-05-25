<#
.SYNOPSIS
    Creates a WPF DataGridTextColumn object.

.DESCRIPTION
    Creates a DataGridTextColumn and auto-attaches it when declared inside a
    DataGrid script block.

    The second argument supports either a binding path string or a pre-built
    System.Windows.Data.Binding object.

.EXAMPLE
    DataGridTextColumn 'Name' 'ProcessName' {
        $this.Width = [System.Windows.Controls.DataGridLength]::new(1, [System.Windows.Controls.DataGridLengthUnitType]::Star)
    }

.EXAMPLE
    DataGridTextColumn 'CPU' (Binding 'CpuPercent') {
        UseStyle 'RightAlignedDataGridHeader' $this -TargetType HeaderStyle
        UseStyle 'RightAlignedDataGridCell' $this -TargetType ElementStyle
    }

.EXAMPLE
    Disable a block of code without commenting it out by using a negative prefix.

    -DataGridTextColumn 'CPU' 'CpuPercent' { ...code... }
#>
function DataGridTextColumn {
    [CmdletBinding()]
    [Alias('-DataGridTextColumn')]
    [OutputType([void], [System.Windows.Controls.DataGridTextColumn])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Header,

        [Parameter(Position = 1)]
        [AllowNull()]
        [object] $Binding,

        [Parameter(Position = 2)]
        [scriptblock] $ScriptBlock
    )

    if ($Binding -is [scriptblock] -and -not $PSBoundParameters.ContainsKey('ScriptBlock')) {
        $ScriptBlock = $Binding
        $Binding = $null
    }

    if (-not $ScriptBlock) {
        $ScriptBlock = {}
    }

    if ($MyInvocation.InvocationName.StartsWith('-')) {
        Write-WPFDisabledBlockWarning -Invocation $MyInvocation -Name $Header
        return
    }

    try {
        $columnBinding = $null
        if ($null -ne $Binding) {
            if ($Binding -is [System.Windows.Data.Binding]) {
                $columnBinding = $Binding
            } elseif ($Binding -is [string]) {
                $columnBinding = [System.Windows.Data.Binding] $Binding
            } else {
                throw "Unsupported binding type '$($Binding.GetType().FullName)'. Use a string path or System.Windows.Data.Binding."
            }
        }

        $DataGridTextColumn = [System.Windows.Controls.DataGridTextColumn]::new()
        $DataGridTextColumn.Header = $Header
        if ($null -ne $columnBinding) {
            $DataGridTextColumn.Binding = $columnBinding
        }

        Add-WPFType $DataGridTextColumn 'DataGridColumn'
    } catch {
        Write-Error "Failed to create '$Header' (DataGridTextColumn) with error: $_"
        return
    }

    $Parent = $PSCmdlet.GetVariableValue('this')
    if ($Parent) {
        Write-Debug "Beginning auto-attach for '$Header' (DataGridTextColumn)"
        Update-WPFObject $Parent $DataGridTextColumn
    }

    Write-Debug "Processing child elements for '$Header' (DataGridTextColumn)"
    Update-WPFObject $DataGridTextColumn $ScriptBlock

    if ($Parent) { return }
    return $DataGridTextColumn
}
