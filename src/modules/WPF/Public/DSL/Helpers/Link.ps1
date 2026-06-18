<#
.SYNOPSIS
    Unified sugar keyword for binding scenarios.

.DESCRIPTION
    Link is a thin wrapper that delegates to existing binding primitives:

    1) State mode: delegates to Bind
    2) Property mode: delegates to BindProperty
    3) AsBinding mode: delegates to Binding and returns a Binding object

    The source-side term is intentionally named -Property, with -Path kept as an
    alias for users who prefer WPF-native terminology.

.EXAMPLE
    Link Visibility -ToState IsFullScreen -Invert

.EXAMPLE
    Link Text -Property Count

.EXAMPLE
    Link Text -Path ItemsSource.Count -Source (Reference 'ProcessList')

.EXAMPLE
    $Binding = Link -AsBinding -Property IsEnabled -Self
#>
function Link {
    [CmdletBinding(DefaultParameterSetName = 'Property')]
    [OutputType([void], [System.Windows.Data.Binding])]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'State')]
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Property')]
        [ValidateNotNullOrEmpty()]
        [string] $TargetProperty,

        [Parameter(Mandatory, ParameterSetName = 'State')]
        [ValidateNotNullOrEmpty()]
        [string] $ToState,

        [Parameter(Mandatory, Position = 1, ParameterSetName = 'Property')]
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'AsBinding')]
        [Alias('Path')]
        [ValidateNotNullOrEmpty()]
        [string] $Property,

        [Parameter(ParameterSetName = 'State')]
        [scriptblock] $Converter,

        [Parameter(ParameterSetName = 'State')]
        [switch] $Invert,

        [Parameter(ParameterSetName = 'Property')]
        [Parameter(ParameterSetName = 'AsBinding')]
        [switch] $Self,

        [Parameter(ParameterSetName = 'Property')]
        [Parameter(ParameterSetName = 'AsBinding')]
        [switch] $TemplatedParent,

        [Parameter(ParameterSetName = 'Property')]
        [Parameter(ParameterSetName = 'AsBinding')]
        [ValidateNotNullOrEmpty()]
        [string] $ElementName,

        [Parameter(ParameterSetName = 'Property')]
        [Parameter(ParameterSetName = 'AsBinding')]
        [AllowNull()]
        [object] $Source,

        [Parameter(ParameterSetName = 'Property')]
        [Parameter(ParameterSetName = 'AsBinding')]
        [scriptblock] $ScriptBlock,

        [Parameter(ParameterSetName = 'State')]
        [Parameter(ParameterSetName = 'Property')]
        [object] $InputObject,

        [Parameter(Mandatory, ParameterSetName = 'AsBinding')]
        [switch] $AsBinding
    )

    process {
        $CurrentInputObject = if ($PSBoundParameters.ContainsKey('InputObject')) {
            $InputObject
        } else {
            $PSCmdlet.GetVariableValue('this')
        }

        switch ($PSCmdlet.ParameterSetName) {
            'State' {
                $Window = Get-WPFWindow
                if ($null -eq $Window -or [string]::IsNullOrWhiteSpace($Window.Name)) {
                    Write-Error 'Link: Unable to resolve the current window context for -ToState mode.'
                    return
                }

                $BindParams = @{
                    Property = $TargetProperty
                    To       = "$($Window.Name).Tag.$ToState"
                }

                if ($PSBoundParameters.ContainsKey('Converter')) {
                    $BindParams.Converter = $Converter
                }

                if ($Invert) {
                    $BindParams.Invert = $true
                }

                if ($null -ne $CurrentInputObject) {
                    $BindParams.InputObject = $CurrentInputObject
                }

                Bind @BindParams
                break
            }
            'Property' {
                $BindPropertyParams = @{
                    Property = $TargetProperty
                    Path     = $Property
                }

                if ($Self) {
                    $BindPropertyParams.Self = $true
                }

                if ($TemplatedParent) {
                    $BindPropertyParams.TemplatedParent = $true
                }

                if ($PSBoundParameters.ContainsKey('ElementName')) {
                    $BindPropertyParams.ElementName = $ElementName
                }

                if ($PSBoundParameters.ContainsKey('Source')) {
                    $BindPropertyParams.Source = $Source
                }

                if ($null -ne $CurrentInputObject) {
                    $BindPropertyParams.InputObject = $CurrentInputObject
                }

                if ($PSBoundParameters.ContainsKey('ScriptBlock')) {
                    $BindPropertyParams.ScriptBlock = $ScriptBlock
                }

                BindProperty @BindPropertyParams
                break
            }
            'AsBinding' {
                $BindingParams = @{
                    Path = $Property
                }

                if ($Self) {
                    $BindingParams.Self = $true
                }

                if ($TemplatedParent) {
                    $BindingParams.TemplatedParent = $true
                }

                if ($PSBoundParameters.ContainsKey('ElementName')) {
                    $BindingParams.ElementName = $ElementName
                }

                if ($PSBoundParameters.ContainsKey('Source')) {
                    $BindingParams.Source = $Source
                }

                if ($PSBoundParameters.ContainsKey('ScriptBlock')) {
                    $BindingParams.ScriptBlock = $ScriptBlock
                }

                return (Binding @BindingParams)
            }
            default {
                Write-Error "Link: Unsupported parameter set '$($PSCmdlet.ParameterSetName)'."
                return
            }
        }
    }
}
