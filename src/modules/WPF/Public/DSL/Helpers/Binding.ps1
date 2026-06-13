<#
.SYNOPSIS
    Creates a WPF Binding object for advanced DSL scenarios.

.DESCRIPTION
    Builds a System.Windows.Data.Binding with common source selectors used by
    DataTrigger and template-driven styles.

    This keyword is optional for BindProperty usage. BindProperty creates and
    applies its own Binding object internally.

    Use this keyword when BindProperty or other DSL APIs need a raw Binding
    object, for example DataTrigger with RelativeSource settings.

.EXAMPLE
    DataTrigger (Binding 'IsEnabled' -Self) $false {
        Setter Opacity 0.4
    }

.EXAMPLE
    DataTrigger (Binding 'IsEnabled' -TemplatedParent) $false {
        Setter Opacity 0.6 -Target 'TemplateRoot'
    }
#>
function Binding {
    [CmdletBinding()]
    [Alias('New-WPFBinding')]
    [OutputType([System.Windows.Data.Binding])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter()]
        [switch] $Self,

        [Parameter()]
        [switch] $TemplatedParent,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ElementName,

        [Parameter()]
        [AllowNull()]
        [object] $Source,

        [Parameter()]
        [scriptblock] $ScriptBlock
    )

    $selectorCount = 0
    if ($Self) { $selectorCount++ }
    if ($TemplatedParent) { $selectorCount++ }
    if ($ElementName) { $selectorCount++ }
    if ($PSBoundParameters.ContainsKey('Source')) { $selectorCount++ }

    if ($selectorCount -gt 1) {
        Write-Error 'Binding: Specify at most one source selector from -Self, -TemplatedParent, -ElementName, or -Source.'
        return
    }

    $binding = [System.Windows.Data.Binding]::new($Path)

    if ($Self) {
        $binding.RelativeSource = [System.Windows.Data.RelativeSource]::new([System.Windows.Data.RelativeSourceMode]::Self)
    } elseif ($TemplatedParent) {
        $binding.RelativeSource = [System.Windows.Data.RelativeSource]::new([System.Windows.Data.RelativeSourceMode]::TemplatedParent)
    } elseif ($ElementName) {
        $binding.ElementName = $ElementName
    } elseif ($PSBoundParameters.ContainsKey('Source')) {
        $binding.Source = $Source
    }

    if ($ScriptBlock) {
        $PSVars = New-WPFVariableList -InputObject $binding
        $null = $ScriptBlock.InvokeWithContext($null, $PSVars)
    }

    return $binding
}
