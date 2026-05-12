<#
.SYNOPSIS
    Binds a dependency property to a binding path using BindingOperations.

.DESCRIPTION
    Establishes a WPF data binding between a control property and a binding source
    (another control, element name, relative source, or arbitrary object).

    Use this keyword to bind regular properties (like TextBlock.Text) to dependency
    properties or observable sources.

    Call inside a DSL control body to bind from $this implicitly, or pass a control
    via -InputObject for use outside a body.

.PARAMETER Property
    The name of the property to bind (e.g., 'Text', 'Visibility', 'IsEnabled').

.PARAMETER Path
    The binding path on the source object (e.g., 'ItemsSource.Count', 'IsChecked').

.PARAMETER Self
    Bind relative to the target control itself using RelativeSource Self.

.PARAMETER TemplatedParent
    Bind relative to the templated parent using RelativeSource TemplatedParent.

.PARAMETER ElementName
    The registered name of another control to bind to.

.PARAMETER Source
    An arbitrary source object to bind to.

.PARAMETER InputObject
    The target control. Accepts pipeline input. Defaults to $this in DSL context.

.PARAMETER ScriptBlock
    Optional scriptblock to configure the binding object (e.g., set Converter, Mode, etc.).

.EXAMPLE
    # Bind TextBlock.Text to DataGrid.ItemsSource.Count
    TextBlock 'ProcessCount' {
        BindProperty Text ItemsSource.Count -Source (Reference 'ProcessList')
    }

.EXAMPLE
    # Bind visibility relative to the target control itself
    Rectangle 'Loading' {
        BindProperty Visibility IsLoading -Self
    }

.EXAMPLE
    # Configure the binding with a converter
    Label 'Status' {
        BindProperty Content CurrentFile -Source (Reference 'Window').Tag -ScriptBlock {
            $this.Converter = New-WPFValueConverter {
                param($File)
                if ($File) { "File: $($File.Name)" } else { 'No file' }
            }
        }
    }

.LINK
    https://learn.microsoft.com/en-us/dotnet/api/system.windows.data.bindingoperations
#>
function BindProperty {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Property,

        [Parameter(Mandatory, Position = 1)]
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

        [Parameter(ValueFromPipeline)]
        [object] $InputObject,

        [Parameter()]
        [scriptblock] $ScriptBlock
    )

    process {
        Write-Verbose "BindProperty: Binding '$Property' to '$Path'."
        $Target = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }

        if (-not $Target) {
            Write-Error "BindProperty: Unable to resolve target object. Use BindProperty inside a DSL control block or pass -InputObject."
            return
        }

        # Validate that only one source selector is specified
        $selectorCount = 0
        if ($Self) { $selectorCount++ }
        if ($TemplatedParent) { $selectorCount++ }
        if ($ElementName) { $selectorCount++ }
        if ($PSBoundParameters.ContainsKey('Source')) { $selectorCount++ }

        if ($selectorCount -gt 1) {
            Write-Error 'BindProperty: Specify at most one source selector from -Self, -TemplatedParent, -ElementName, or -Source.'
            return
        }

        if ($selectorCount -eq 0) {
            Write-Error 'BindProperty: You must specify a source selector: -Self, -TemplatedParent, -ElementName, or -Source.'
            return
        }

        # Resolve the target dependency property descriptor
        $TargetType = $Target.GetType()
        $DepPropDescriptor = [System.ComponentModel.DependencyPropertyDescriptor]::FromName($Property, $TargetType, $TargetType)

        if (-not $DepPropDescriptor) {
            Write-Error "BindProperty: Property '$Property' is not a valid dependency property on type '$($TargetType.FullName)'."
            return
        }

        # Create the binding
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

        # Allow custom configuration via scriptblock
        if ($ScriptBlock) {
            $PSVars = New-WPFVariableList -InputObject $binding
            $null = $ScriptBlock.InvokeWithContext($null, $PSVars)
        }

        # Apply the binding using BindingOperations
        $null = [System.Windows.Data.BindingOperations]::SetBinding($Target, $DepPropDescriptor.DependencyProperty, $binding)
        Write-Verbose "BindProperty: Successfully bound '$Property' on $($TargetType.Name) to '$Path'."
    }
}
