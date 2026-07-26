<#
.SYNOPSIS
    Unified sugar keyword for binding scenarios.

.DESCRIPTION
    Link is a thin wrapper that delegates to existing binding primitives:

    1) State mode: delegates to Bind
    2) Directional mode: resolves endpoints and delegates to Bind/BindProperty
    3) AsBinding mode: delegates to Binding and returns a Binding object

    Directionality contract: Link always applies values in one direction,
    from source to target. This avoids ambiguous interpretations where both
    endpoints could be read or written.

    The canonical Link shape is source-to-target:
    Link <Source> -To <Target>

.EXAMPLE
    Link Visibility -FromState IsFullScreen -Invert

.EXAMPLE
    Link ToolTip -FromState IsCopyFeedbackActive -Map @{
        $true  = 'Copied to clipboard'
        $false = 'Copy image to clipboard'
    }

.EXAMPLE
    $Binding = Link -AsBinding -Property IsEnabled -Self

.EXAMPLE
    # Canonical directional form (source -> target)
    Link IsFileLoaded -To IsEnabled

.EXAMPLE
    # Property -> State directional form
    Link Text -To SearchQuery
#>
function Link {
    [CmdletBinding(DefaultParameterSetName = 'Directional')]
    [OutputType([void], [System.Windows.Data.Binding])]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Directional')]
        [ValidateNotNullOrEmpty()]
        [string] $From,

        [Parameter(Mandatory, ParameterSetName = 'Directional')]
        [ValidateNotNullOrEmpty()]
        [string] $To,

        [Parameter(ParameterSetName = 'Directional')]
        [ValidateSet('Property', 'State')]
        [string] $FromKind,

        [Parameter(ParameterSetName = 'Directional')]
        [ValidateSet('Property', 'State')]
        [string] $ToKind,

        [Parameter(Mandatory, Position = 0, ParameterSetName = 'State')]
        [ValidateNotNullOrEmpty()]
        [string] $TargetProperty,

        [Parameter(Mandatory, ParameterSetName = 'State')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({ Complete-WPFState @args })]
        [string] $FromState,

        [Parameter(Mandatory, Position = 0, ParameterSetName = 'AsBinding')]
        [Alias('Path')]
        [ValidateNotNullOrEmpty()]
        [string] $Property,

        [Parameter(ParameterSetName = 'State')]
        [Parameter(ParameterSetName = 'Directional')]
        [scriptblock] $Transform,

        [Parameter(ParameterSetName = 'State')]
        [Parameter(ParameterSetName = 'Directional')]
        [hashtable] $Map,

        [Parameter(ParameterSetName = 'State')]
        [Parameter(ParameterSetName = 'Directional')]
        [AllowNull()]
        [object] $Default,

        [Parameter(ParameterSetName = 'State')]
        [Parameter(ParameterSetName = 'Directional')]
        [switch] $StrictMap,

        [Parameter(ParameterSetName = 'State')]
        [Parameter(ParameterSetName = 'Directional')]
        [switch] $Invert,

        [Parameter(ParameterSetName = 'AsBinding')]
        [switch] $Self,

        [Parameter(ParameterSetName = 'AsBinding')]
        [switch] $TemplatedParent,

        [Parameter(ParameterSetName = 'AsBinding')]
        [ValidateNotNullOrEmpty()]
        [string] $ElementName,

        [Parameter(ParameterSetName = 'AsBinding')]
        [AllowNull()]
        [object] $Source,

        [Parameter(ParameterSetName = 'AsBinding')]
        [scriptblock] $ScriptBlock,

        [Parameter(ParameterSetName = 'State')]
        [Parameter(ParameterSetName = 'Directional')]
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

        $HasMapParameter = $PSBoundParameters.ContainsKey('Map')
        $HasDefaultParameter = $PSBoundParameters.ContainsKey('Default')
        $HasTransformParameter = $PSBoundParameters.ContainsKey('Transform')

        $InvokeStateToProperty = {
            param(
                [string] $ResolvedTargetProperty,
                [string] $ResolvedSourceState
            )

            $HasMap = $HasMapParameter
            $HasDefault = $HasDefaultParameter

            if ($HasMap -and $HasTransformParameter) {
                Write-Error 'Link: Specify either -Map or -Transform in state mode, not both.'
                return
            }

            if (-not $HasMap -and ($HasDefault -or $StrictMap)) {
                Write-Error 'Link: -Default and -StrictMap require -Map in state mode.'
                return
            }

            if ($HasDefault -and $StrictMap) {
                Write-Error 'Link: -Default and -StrictMap cannot be combined in state mode.'
                return
            }

            $Window = Get-WPFWindow
            if ($null -eq $Window -or [string]::IsNullOrWhiteSpace($Window.Name)) {
                Write-Error 'Link: Unable to resolve the current window context for state sourcing.'
                return
            }

            $BindParams = @{
                Property = $ResolvedTargetProperty
                To       = "$($Window.Name).Tag.$ResolvedSourceState"
            }

            if ($HasMap) {
                $MapValues = $Map
                $UseStrictMap = [bool] $StrictMap
                $UseDefaultMapValue = $HasDefault
                $DefaultMapValue = $Default

                $ScriptBlockMapKeys = @()
                foreach ($MapKey in $MapValues.Keys) {
                    if ($MapValues[$MapKey] -is [scriptblock]) {
                        $ScriptBlockMapKeys += [string] $MapKey
                    }
                }

                if ($ScriptBlockMapKeys.Count -gt 0) {
                    $ScriptBlockMapKeyList = $ScriptBlockMapKeys -join ', '
                    Write-Warning "Link: -Map contains scriptblock value(s) for key(s): $ScriptBlockMapKeyList. Use evaluated values/objects in -Map (for example, wrap Path calls in parentheses)."
                }

                $BindParams.Converter = {
                    param($SourceValue)

                    if ($MapValues.Contains($SourceValue)) {
                        return $MapValues[$SourceValue]
                    }

                    # Helpful fallback for common boolean map literals like True/False.
                    if ($SourceValue -is [bool]) {
                        $BoolKeyText = if ($SourceValue) { 'True' } else { 'False' }
                        if ($MapValues.Contains($BoolKeyText)) {
                            return $MapValues[$BoolKeyText]
                        }
                    }

                    if ($UseDefaultMapValue) {
                        return $DefaultMapValue
                    }

                    if ($UseStrictMap) {
                        throw "Link: -Map has no entry for source value '$SourceValue'."
                    }

                    return $SourceValue
                }.GetNewClosure()
            } elseif ($HasTransformParameter) {
                $BindParams.Converter = $Transform
            }

            if ($Invert) {
                $BindParams.Invert = $true
            }

            if ($null -ne $CurrentInputObject) {
                $BindParams.InputObject = $CurrentInputObject
            }

            Bind @BindParams
        }.GetNewClosure()

        $InvokeStateToState = {
            param(
                [string] $ResolvedSourceState,
                [string] $ResolvedTargetState,
                [object] $ResolvedStateObject
            )

            if ([string]::Equals($ResolvedSourceState, $ResolvedTargetState, [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-Error "Link: Directional State -> State links require distinct endpoints. Source and target were both '$ResolvedSourceState'."
                return
            }

            $HasMap = $HasMapParameter
            $HasDefault = $HasDefaultParameter

            if ($HasMap -and $HasTransformParameter) {
                Write-Error 'Link: Specify either -Map or -Transform in state mode, not both.'
                return
            }

            if (-not $HasMap -and ($HasDefault -or $StrictMap)) {
                Write-Error 'Link: -Default and -StrictMap require -Map in state mode.'
                return
            }

            if ($HasDefault -and $StrictMap) {
                Write-Error 'Link: -Default and -StrictMap cannot be combined in state mode.'
                return
            }

            if ($null -eq $ResolvedStateObject) {
                Write-Error 'Link: Unable to resolve state object for directional State -> State mode.'
                return
            }

            $AddBindingMethod = $ResolvedStateObject.PSObject.Methods['AddBinding']
            if ($null -eq $AddBindingMethod) {
                Write-Error "Link: State object does not support AddBinding(). Use State @{ ... } to create observable state first."
                return
            }

            $SetValueMethod = $ResolvedStateObject.PSObject.Methods['SetValue']
            $GetValueMethod = $ResolvedStateObject.PSObject.Methods['GetValue']
            $ContainsPropertyMethod = $ResolvedStateObject.PSObject.Methods['ContainsProperty']

            if ($null -ne $ContainsPropertyMethod) {
                if (-not $ResolvedStateObject.ContainsProperty($ResolvedSourceState)) {
                    Write-Error "Link: Source state property '$ResolvedSourceState' does not exist."
                    return
                }

                if (-not $ResolvedStateObject.ContainsProperty($ResolvedTargetState)) {
                    Write-Error "Link: Target state property '$ResolvedTargetState' does not exist."
                    return
                }
            }

            $StateCallback = {
                param($SourceValue)

                $FinalValue = if ($Invert) { -not $SourceValue } else { $SourceValue }

                if ($HasMap) {
                    if ($Map.Contains($FinalValue)) {
                        $FinalValue = $Map[$FinalValue]
                    } elseif ($FinalValue -is [bool]) {
                        $BoolKeyText = if ($FinalValue) { 'True' } else { 'False' }
                        if ($Map.Contains($BoolKeyText)) {
                            $FinalValue = $Map[$BoolKeyText]
                        } elseif ($HasDefault) {
                            $FinalValue = $Default
                        } elseif ($StrictMap) {
                            throw "Link: -Map has no entry for source value '$FinalValue'."
                        }
                    } elseif ($HasDefault) {
                        $FinalValue = $Default
                    } elseif ($StrictMap) {
                        throw "Link: -Map has no entry for source value '$FinalValue'."
                    }
                } elseif ($HasTransformParameter) {
                    $HasParams = $Transform.Ast.ParamBlock -and $Transform.Ast.ParamBlock.Parameters.Count -gt 0
                    if ($HasParams) {
                        $FinalValue = & $Transform $FinalValue
                    } else {
                        $PSVars = [System.Collections.Generic.List[psvariable]]::new()
                        $PSVars.Add([psvariable]::new('_', $FinalValue))
                        $PSVars.Add([psvariable]::new('PSItem', $FinalValue))
                        $results = $Transform.InvokeWithContext($null, $PSVars)
                        if ($results.Count -gt 0) {
                            $FinalValue = $results[0]
                        }
                    }
                }

                if ($null -ne $GetValueMethod) {
                    $CurrentTargetValue = $ResolvedStateObject.GetValue($ResolvedTargetState)
                    if ([object]::Equals($CurrentTargetValue, $FinalValue)) {
                        return
                    }
                }

                if ($null -ne $SetValueMethod) {
                    $ResolvedStateObject.SetValue($ResolvedTargetState, $FinalValue)
                } else {
                    $StateProperty = $ResolvedStateObject.PSObject.Properties[$ResolvedTargetState]
                    if ($null -eq $StateProperty) {
                        throw "Link: Target state property '$ResolvedTargetState' does not exist."
                    }

                    $ResolvedStateObject.$ResolvedTargetState = $FinalValue
                }
            }.GetNewClosure()

            $ResolvedStateObject.AddBinding($ResolvedSourceState, $StateCallback)
        }.GetNewClosure()

        $TestMemberExists = {
            param(
                [object] $InputObject,
                [string] $MemberName
            )

            if ($null -eq $InputObject -or [string]::IsNullOrWhiteSpace($MemberName)) {
                return $false
            }

            if ($InputObject.PSObject.Methods['ContainsProperty']) {
                try {
                    return [bool] ($InputObject.ContainsProperty($MemberName))
                } catch {
                    # Fall through to reflection-based checks.
                }
            }

            if ($null -ne $InputObject.PSObject.Properties[$MemberName]) {
                return $true
            }

            $Member = $InputObject.GetType().GetProperty($MemberName)
            return ($null -ne $Member)
        }.GetNewClosure()

        $ResolveEndpointKind = {
            param(
                [string] $EndpointName,
                [string] $RequestedKind,
                [ValidateSet('Source', 'Target')]
                [string] $EndpointRole,
                [bool] $PropertyExists,
                [bool] $StateExists
            )

            $Kinds = @()
            if ($PropertyExists) {
                $Kinds += 'Property'
            }

            if ($StateExists) {
                $Kinds += 'State'
            }

            if (-not [string]::IsNullOrWhiteSpace($RequestedKind)) {
                if (-not ($Kinds -contains $RequestedKind)) {
                    Write-Error "Link: $EndpointRole '$EndpointName' does not exist as $RequestedKind in the current context."
                    return $null
                }

                return $RequestedKind
            }

            if ($Kinds.Count -eq 0) {
                Write-Error "Link: $EndpointRole '$EndpointName' was not found in current control properties or window state."
                return $null
            }

            if ($Kinds.Count -gt 1) {
                $KindParameter = if ($EndpointRole -eq 'Source') { '-FromKind' } else { '-ToKind' }
                Write-Error "Link: $EndpointRole '$EndpointName' is ambiguous (Property and State). Specify $KindParameter Property or State."
                return $null
            }

            return $Kinds[0]
        }.GetNewClosure()

        switch ($PSCmdlet.ParameterSetName) {
            'Directional' {
                $Window = Get-WPFWindow
                if ($null -eq $Window -or [string]::IsNullOrWhiteSpace($Window.Name)) {
                    Write-Error 'Link: Unable to resolve the current window context for directional mode.'
                    return
                }

                $State = $Window.Tag
                $SourcePropertyExists = & $TestMemberExists -InputObject $CurrentInputObject -MemberName $From
                $SourceStateExists = & $TestMemberExists -InputObject $State -MemberName $From
                $TargetPropertyExists = & $TestMemberExists -InputObject $CurrentInputObject -MemberName $To
                $TargetStateExists = & $TestMemberExists -InputObject $State -MemberName $To

                $ResolvedSourceKind = & $ResolveEndpointKind `
                    -EndpointName $From `
                    -RequestedKind $FromKind `
                    -EndpointRole Source `
                    -PropertyExists $SourcePropertyExists `
                    -StateExists $SourceStateExists

                if ($null -eq $ResolvedSourceKind) {
                    return
                }

                $ResolvedTargetKind = & $ResolveEndpointKind `
                    -EndpointName $To `
                    -RequestedKind $ToKind `
                    -EndpointRole Target `
                    -PropertyExists $TargetPropertyExists `
                    -StateExists $TargetStateExists

                if ($null -eq $ResolvedTargetKind) {
                    return
                }

                if ($ResolvedSourceKind -eq 'State' -and $ResolvedTargetKind -eq 'Property') {
                    & $InvokeStateToProperty -ResolvedTargetProperty $To -ResolvedSourceState $From
                    break
                }

                if ($ResolvedSourceKind -eq 'Property' -and $ResolvedTargetKind -eq 'Property') {
                    if ($HasMapParameter -or
                        $HasTransformParameter -or
                        $PSBoundParameters.ContainsKey('Default') -or
                        $PSBoundParameters.ContainsKey('StrictMap') -or
                        $PSBoundParameters.ContainsKey('Invert')) {
                        Write-Error 'Link: -Map, -Transform, -Default, -StrictMap, and -Invert are not supported for Property -> Property directional links.'
                        return
                    }

                    $BindPropertyParams = @{
                        Property    = $To
                        Path        = $From
                        Self        = $true
                        InputObject = $CurrentInputObject
                    }

                    BindProperty @BindPropertyParams
                    break
                }

                if ($ResolvedSourceKind -eq 'Property' -and $ResolvedTargetKind -eq 'State') {
                    if ($HasMapParameter -and $HasTransformParameter) {
                        Write-Error 'Link: Specify either -Map or -Transform in directional Property -> State mode, not both.'
                        return
                    }

                    if (-not $HasMapParameter -and ($PSBoundParameters.ContainsKey('Default') -or $PSBoundParameters.ContainsKey('StrictMap'))) {
                        Write-Error 'Link: -Default and -StrictMap require -Map in directional Property -> State mode.'
                        return
                    }

                    if ($PSBoundParameters.ContainsKey('Default') -and $PSBoundParameters.ContainsKey('StrictMap')) {
                        Write-Error 'Link: -Default and -StrictMap cannot be combined in directional Property -> State mode.'
                        return
                    }

                    $UseStrictMap = [bool] $StrictMap
                    $UseDefaultMapValue = $PSBoundParameters.ContainsKey('Default')
                    $DefaultMapValue = $Default

                    if ($HasMapParameter) {
                        $ScriptBlockMapKeys = @()
                        foreach ($MapKey in $Map.Keys) {
                            if ($Map[$MapKey] -is [scriptblock]) {
                                $ScriptBlockMapKeys += [string] $MapKey
                            }
                        }

                        if ($ScriptBlockMapKeys.Count -gt 0) {
                            $ScriptBlockMapKeyList = $ScriptBlockMapKeys -join ', '
                            Write-Warning "Link: -Map contains scriptblock value(s) for key(s): $ScriptBlockMapKeyList. Use evaluated values/objects in -Map (for example, wrap Path calls in parentheses)."
                        }
                    }

                    $DirectionalValueConverter = {
                        param($Value)

                        $FinalValue = $Value

                        if ($Invert) {
                            $FinalValue = -not $FinalValue
                        }

                        if ($HasMapParameter) {
                            if ($Map.Contains($FinalValue)) {
                                return $Map[$FinalValue]
                            }

                            if ($FinalValue -is [bool]) {
                                $BoolKeyText = if ($FinalValue) { 'True' } else { 'False' }
                                if ($Map.Contains($BoolKeyText)) {
                                    return $Map[$BoolKeyText]
                                }
                            }

                            if ($UseDefaultMapValue) {
                                return $DefaultMapValue
                            }

                            if ($UseStrictMap) {
                                throw "Link: -Map has no entry for source value '$FinalValue'."
                            }

                            return $FinalValue
                        }

                        if ($HasTransformParameter) {
                            $TransformScript = $Transform
                            $HasParams = $TransformScript.Ast.ParamBlock -and $TransformScript.Ast.ParamBlock.Parameters.Count -gt 0
                            if ($HasParams) {
                                return (& $TransformScript $FinalValue)
                            }

                            $PSVars = [System.Collections.Generic.List[psvariable]]::new()
                            $PSVars.Add([psvariable]::new('_', $FinalValue))
                            $PSVars.Add([psvariable]::new('PSItem', $FinalValue))
                            $results = $TransformScript.InvokeWithContext($null, $PSVars)
                            if ($results.Count -gt 0) {
                                return $results[0]
                            }
                        }

                        return $FinalValue
                    }.GetNewClosure()

                    $DirectionalScriptBlock = {
                        $this.Mode = [System.Windows.Data.BindingMode]::OneWayToSource
                        $this.UpdateSourceTrigger = [System.Windows.Data.UpdateSourceTrigger]::PropertyChanged
                        $this.Converter = New-WPFValueConverter $DirectionalValueConverter $DirectionalValueConverter
                    }

                    $BindPropertyParams = @{
                        Property    = $From
                        Path        = $To
                        Source      = $State
                        InputObject = $CurrentInputObject
                        ScriptBlock = $DirectionalScriptBlock
                    }

                    BindProperty @BindPropertyParams
                    break
                }

                if ($ResolvedSourceKind -eq 'State' -and $ResolvedTargetKind -eq 'State') {
                    & $InvokeStateToState -ResolvedSourceState $From -ResolvedTargetState $To -ResolvedStateObject $State
                    break
                }

                Write-Error "Link: Directional mode does not yet support Source=$ResolvedSourceKind and Target=$ResolvedTargetKind."
                return
            }
            'State' {
                & $InvokeStateToProperty -ResolvedTargetProperty $TargetProperty -ResolvedSourceState $FromState
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
