function Test-WPFType {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [ValidateSet(
            'Control', 'Handler', 'Shape', 'GridDefinition',
            'Command', 'DataGridColumn', 'ListViewView',
            'GridViewColumn', 'CollectorOwner'
        )]
        [string[]] $Type
    )

    foreach ($TypeEntry in $Type) {
        if ($InputObject.PSObject.TypeNames -contains "Custom.WPF.$TypeEntry") {
            return $True
        }
    }
    return $False
}
