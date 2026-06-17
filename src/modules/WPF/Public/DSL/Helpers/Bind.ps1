<#
.SYNOPSIS
    Registers a reactive property binding between a control and an observable state property.

.DESCRIPTION
    Wires a control property to an observable state property created by
    New-WPFObservableState. Whenever the source property changes, the target
    property is updated automatically.

    Call inside a DSL control body to Bind from $this implicitly, or pass a control
    via -InputObject for use outside a body.

    -To format: "RegisteredName[.NavigationPath].PropertyName"
    The first segment is resolved via Reference, intermediate segments navigate
    sub-objects, and the last segment is the observable property to watch.

    For Visibility bindings a boolean source value is automatically converted:
        $true  -> Visible
        $false -> Collapsed

.NOTES
    The built-in conversion behavior should only support common cases that are
    predictable, and low-surprise across many scripts. Not for one-offs or
    convenience that only helps a single example.

    For uncommon cases, use a custom converter scriptblock that transforms the
    source value as needed before assignment.

.PARAMETER Property
    The property name to update on the target control (e.g. 'Visibility', 'IsEnabled').

.PARAMETER To
    Dot-notation path to the observable state property.
    Example: 'Window.Tag.IsFullScreen'

.PARAMETER Converter
    Optional scriptblock to transform the (possibly inverted) source value before
    assignment. Converters can use either style: declare param($Value) for a named parameter,
    or use $_ / PSItem implicitly. Both receive the value automatically.

.PARAMETER Invert
    Inverts boolean source values before conversion or assignment.

.PARAMETER InputObject
    The target control. Accepts pipeline input. Defaults to $this in DSL context.

.EXAMPLE
    # Inside a control body - hides menu when fullscreen
    Menu 'Menu' {
        Bind Visibility -To Window.Tag.IsFullScreen -Invert
        ...
    }

.EXAMPLE
    # Enable buttons only when a file is loaded
    Button 'BackButton' {
        Bind IsEnabled -To Window.Tag.IsFileLoaded
        ...
    }

.EXAMPLE
    # Using a converter with implicit $_

    Label 'Status' {
        Bind Content -To Window.Tag.CurrentFile -Converter {
            if ($_) { "File: $($_.Name)" } else { 'No file loaded' }
        }
        ...
    }

.EXAMPLE
    # Using a converter with named parameter

    Label 'Status' {
        Bind Content -To Window.Tag.CurrentFile -Converter {
            param($File)
            if ($File) { "File: $($File.Name)" } else { 'No file loaded' }
        }
        ...
    }
#>
function Bind {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Property,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $To,

        [Parameter(Position = 2)]
        [scriptblock] $Converter,

        [Parameter()]
        [switch] $Invert,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        Write-Verbose "Bind: Resolving target object for property '$Property' from source path '$To'."
        $Target = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }

        if (-not $Target) {
            Write-Error "Bind: Unable to resolve target object. Use Bind inside a DSL control block or pass -InputObject."
            return
        }

        # Resolve "RegisteredName[.Segment...].PropertyName":
        # first segment -> Reference lookup, intermediates -> navigation, last -> property name
        $Parts = $To.Split('.')
        if ($Parts.Length -lt 2) {
            Write-Error "Bind: -To '$To' must include at least one navigation/property segment (example: Window.Tag.IsFullScreen)."
            return
        }

        Write-Verbose "Bind: Resolving source root '$($Parts[0])'."
        $Source = Reference $Parts[0]
        for ($i = 1; $i -lt ($Parts.Length - 1); $i++) {
            Write-Verbose "Bind: Navigating source segment '$($Parts[$i])'."
            $Source = $Source.($Parts[$i])
        }
        $SourceProp = $Parts[-1]

        if ($null -eq $Source) {
            Write-Error "Bind: Failed to resolve source object for path '$To'."
            return
        }

        $callback = {
            param($SourceValue)
            $FinalValue = if ($Invert) { -not $SourceValue } else { $SourceValue }
            if ($Converter) {
                $HasParams = $Converter.Ast.ParamBlock -and $Converter.Ast.ParamBlock.Parameters.Count -gt 0
                if ($HasParams) {
                    # Converter declares parameters: call with positional argument
                    $FinalValue = & $Converter $FinalValue
                } else {
                    # Converter is paramless: inject $_ and PSItem into its scope via InvokeWithContext
                    #
                    # IMPLEMENTATION NOTE:
                    # This is a bit hacky but it allows for more natural converter scriptblocks that don't
                    # require explicit parameters, which can be nice for simple transformations. Probably
                    # don't want to run this in a tight loop or with high frequency since it creates new
                    # variables and scope on each invocation. For typical UI scenarios like user clicks a
                    # button and we want to show temporary feedback, the performance should be just fine.
                    $PSVars = [System.Collections.Generic.List[psvariable]]::new()
                    $PSVars.Add([psvariable]::new('_', $FinalValue))
                    $PSVars.Add([psvariable]::new('PSItem', $FinalValue))
                    $results = $Converter.InvokeWithContext($null, $PSVars)
                    $FinalValue = if ($results.Count -gt 0) { $results[0] } else { $FinalValue }
                }
            }
            if ($Property -eq 'Visibility' -and $FinalValue -is [bool]) {
                $FinalValue = if ($FinalValue) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
            }
            $Target.$Property = $FinalValue
        }.GetNewClosure()

        $TargetName = if ($Target.PSObject.Properties['Name']) { $Target.Name } else { '<unnamed>' }
        Write-Debug "Bind registered: Source='$To' (property '$SourceProp') -> Target='$TargetName.$Property'; Invert=$Invert; ConverterPresent=$($null -ne $Converter)"
        Write-Verbose "Bind: Registering callback and applying initial value for '$Property'."
        $Source.AddBinding($SourceProp, $callback)
    }
}
