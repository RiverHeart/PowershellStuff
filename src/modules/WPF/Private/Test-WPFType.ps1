function Test-WPFType {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [ValidateSet(
            'Control', 'Handler', 'Shape', 'GridDefinition',
            'Command'
        )]
        [string] $Type
    )

    return $InputObject.PSObject.TypeNames -contains "Custom.WPF.$Type"
}
