<#
.SYNOPSIS
    Registers a reactive property binding between a control and an observable state property.

.DESCRIPTION
    Wires a control property to an observable state property created by
    New-WPFObservableState. Whenever the source property changes, the target
    property is updated automatically.

    Call inside a DSL control body to react from $this implicitly, or pass a control
    via -InputObject for use outside a body.

    SourcePath format: "RegisteredName[.NavigationPath].PropertyName"
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

.PARAMETER SourcePath
    Dot-notation path to the observable state property.
    Example: 'Window.Tag.IsFullScreen'

.PARAMETER Converter
    Optional scriptblock to transform the (possibly inverted) source value before
    assignment. Receives the value as $args[0].

.PARAMETER Invert
    Inverts boolean source values before conversion or assignment.

.PARAMETER InputObject
    The target control. Accepts pipeline input. Defaults to $this in DSL context.

.EXAMPLE
    # Inside a control body - hides menu when fullscreen
    MenuBar 'Menu' {
        React Visibility Window.Tag.IsFullScreen -Invert
        ...
    }

.EXAMPLE
    # Enable buttons only when a file is loaded
    Button 'BackButton' {
        React IsEnabled Window.Tag.IsFileLoaded
        ...
    }

.EXAMPLE
    # Using a converter to react a non-boolean property

    Label 'Status' {
        React Content Window.Tag.CurrentFile -Converter {
            if ($args[0]) {
                "File: $args[0].Name"
            } else {
                "No file loaded"
            }
        }
        ...
    }
#>
function React {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Property,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $SourcePath,

        [Parameter(Position = 2)]
        [scriptblock] $Converter,

        [Parameter()]
        [switch] $Invert,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        Write-Verbose "React: Resolving target object for property '$Property' from source path '$SourcePath'."
        $target = if ($null -ne $InputObject) { $InputObject } else { $PSCmdlet.GetVariableValue('this') }

        if (-not $target) {
            Write-Error "React: Unable to resolve target object. Use React inside a DSL control block or pass -InputObject."
            return
        }

        # Resolve "RegisteredName[.Segment...].PropertyName":
        # first segment -> Reference lookup, intermediates -> navigation, last -> property name
        $parts  = $SourcePath.Split('.')
        if ($parts.Length -lt 2) {
            Write-Error "React: SourcePath '$SourcePath' must include at least one navigation/property segment (example: Window.Tag.IsFullScreen)."
            return
        }

        Write-Verbose "React: Resolving source root '$($parts[0])'."
        $source = Reference $parts[0]
        for ($i = 1; $i -lt ($parts.Length - 1); $i++) {
            Write-Verbose "React: Navigating source segment '$($parts[$i])'."
            $source = $source.($parts[$i])
        }
        $sourceProp = $parts[-1]

        if ($null -eq $source) {
            Write-Error "React: Failed to resolve source object for path '$SourcePath'."
            return
        }

        # Capture locals so the deferred callback closure has stable references
        $tgt  = $target
        $prop = $Property
        $conv = $Converter
        $inv  = $Invert.IsPresent

        $callback = {
            param($value)
            $v = if ($inv) { -not $value } else { $value }
            $v = if ($null -ne $conv) { & $conv $v } else { $v }
            if ($prop -eq 'Visibility' -and $v -is [bool]) {
                $v = if ($v) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
            }
            $tgt.$prop = $v
        }.GetNewClosure()

        $targetName = if ($target.PSObject.Properties['Name']) { $target.Name } else { '<unnamed>' }
        Write-Debug "React registered: Source='$SourcePath' (property '$sourceProp') -> Target='$targetName.$Property'; Invert=$inv; ConverterPresent=$($null -ne $conv)"
        Write-Verbose "React: Registering callback and applying initial value for '$Property'."
        $source.AddBinding($sourceProp, $callback)
    }
}
