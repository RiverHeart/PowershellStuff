<#
.SYNOPSIS
	Links WPF control properties and observable state.

.DESCRIPTION
	Resolves source and target endpoint kinds, then delegates binding mechanics
	to the appropriate Link connector. Directional links flow from source to
	target; use -Sync for two-way Property and State synchronization.

	Endpoints are exact top-level member names in one of two namespaces: a
	property on the current control, or a property in the root window State.
	They are resolved eagerly so ambiguous or missing endpoints fail before a
	connector is selected.

	Link intentionally does not interpret endpoints as WPF Binding.Path values
	or inspect inherited DataContext. Use BindProperty for dotted paths, source
	selectors, deferred DataContext resolution, or custom WPF binding settings.
	This is a contract boundary for consistent directional inference across all
	Property/State pairings, not a limitation of WPF binding.

.EXAMPLE
	Link IsFullScreen -To Visibility -Invert

.EXAMPLE
	Link Text -To SearchQuery -Sync

.NOTES
	Link connectors use different underlying mechanisms depending on endpoint
	kinds. The exact-member contract is the common behavior that can be validated
	consistently before dispatch; richer WPF binding semantics remain available
	through BindProperty and Binding.
#>
function Link {
	[CmdletBinding()]
	[OutputType([void])]
	param(
		[Parameter(Mandatory, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string] $From,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string] $To,

		[ValidateSet('Property', 'State')]
		[string] $FromKind,

		[ValidateSet('Property', 'State')]
		[string] $ToKind,

		[scriptblock] $Transform,

		[hashtable] $Map,

		[AllowNull()]
		[object] $Default,

		[switch] $StrictMap,

		[switch] $Invert,

		[switch] $Sync,

		[object] $InputObject
	)

	process {
		$CurrentInputObject = if ($PSBoundParameters.ContainsKey('InputObject')) {
			$InputObject
		} else {
			$PSCmdlet.GetVariableValue('this')
		}

		$SourcePropertyExists = Test-WPFLinkMember -InputObject $CurrentInputObject -MemberName $From
		$TargetPropertyExists = Test-WPFLinkMember -InputObject $CurrentInputObject -MemberName $To
		$Window = $null
		$State = $null

		if ($FromKind -ne 'Property' -or $ToKind -ne 'Property') {
			$Window = Get-WPFWindow
			if ($null -eq $Window -or [string]::IsNullOrWhiteSpace($Window.Name)) {
				Write-Error 'Link: Unable to resolve the current window context for directional mode.'
				return
			}

			$State = $Window.Tag
		}

		$SourceStateExists = Test-WPFLinkMember -InputObject $State -MemberName $From
		$TargetStateExists = Test-WPFLinkMember -InputObject $State -MemberName $To

		$ResolvedSourceKind = Resolve-WPFLinkEndpointKind `
			-EndpointName $From `
			-RequestedKind $FromKind `
			-EndpointRole Source `
			-PropertyExists $SourcePropertyExists `
			-StateExists $SourceStateExists
		if ($null -eq $ResolvedSourceKind) { return }

		$ResolvedTargetKind = Resolve-WPFLinkEndpointKind `
			-EndpointName $To `
			-RequestedKind $ToKind `
			-EndpointRole Target `
			-PropertyExists $TargetPropertyExists `
			-StateExists $TargetStateExists
		if ($null -eq $ResolvedTargetKind) { return }

		$HasMap = $PSBoundParameters.ContainsKey('Map')
		$HasTransform = $PSBoundParameters.ContainsKey('Transform')
		$HasDefault = $PSBoundParameters.ContainsKey('Default')
		$ValueOptions = @{
			HasMap       = $HasMap
			HasTransform = $HasTransform
			HasDefault   = $HasDefault
			UseStrictMap = [bool] $StrictMap
			UseInvert    = [bool] $Invert
			Map          = $Map
			Default      = $Default
			Transform    = $Transform
		}

		if ($Sync) {
			if ($HasMap -or $HasTransform -or $HasDefault -or $StrictMap -or $Invert) {
				Write-Error 'Link: -Sync does not support -Map, -Transform, -Default, -StrictMap, or -Invert.'
				return
			}

			if ($ResolvedSourceKind -eq 'State' -and $ResolvedTargetKind -eq 'Property') {
				$InitialSourceValue = if ($State.PSObject.Methods['GetValue']) {
					$State.GetValue($From)
				} else {
					$State.$From
				}

				Connect-WPFLinkPropertyToState -SourceProperty $To -TargetState $From -State $State -InputObject $CurrentInputObject @ValueOptions
				Connect-WPFLinkStateToProperty -TargetProperty $To -SourceState $From -WindowName $Window.Name -InputObject $CurrentInputObject @ValueOptions

				if ($State.PSObject.Methods['SetValue']) {
					$State.SetValue($From, $InitialSourceValue)
				} else {
					$State.$From = $InitialSourceValue
				}
				return
			}

			if ($ResolvedSourceKind -eq 'Property' -and $ResolvedTargetKind -eq 'State') {
				Connect-WPFLinkPropertyToState -SourceProperty $From -TargetState $To -State $State -InputObject $CurrentInputObject @ValueOptions
				Connect-WPFLinkStateToProperty -TargetProperty $From -SourceState $To -WindowName $Window.Name -InputObject $CurrentInputObject @ValueOptions
				return
			}

			Write-Error 'Link: -Sync is only supported for Property and State directional links.'
			return
		}

		if ($ResolvedSourceKind -eq 'Property' -and $ResolvedTargetKind -eq 'Property') {
			if ($HasMap -or $HasTransform -or $HasDefault -or $StrictMap -or $Invert) {
				Write-Error 'Link: -Map, -Transform, -Default, -StrictMap, and -Invert are not supported for Property -> Property directional links.'
				return
			}
			Connect-WPFLinkPropertyToProperty -SourceProperty $From -TargetProperty $To -InputObject $CurrentInputObject
			return
		}

		$ValueOptionError = Get-WPFLinkValueOptionError `
			-HasMap $HasMap `
			-HasTransform $HasTransform `
			-HasDefault $HasDefault `
			-UseStrictMap ([bool] $StrictMap)
		if ($null -ne $ValueOptionError) {
			if ($ResolvedSourceKind -eq 'State') {
				Write-Error $ValueOptionError -ErrorAction Continue
			} else {
				Write-Error $ValueOptionError
			}
			return
		}

		if ($ResolvedSourceKind -eq 'State' -and $ResolvedTargetKind -eq 'Property') {
			Connect-WPFLinkStateToProperty -TargetProperty $To -SourceState $From -WindowName $Window.Name -InputObject $CurrentInputObject @ValueOptions
			return
		}

		if ($ResolvedSourceKind -eq 'Property' -and $ResolvedTargetKind -eq 'State') {
			Connect-WPFLinkPropertyToState -SourceProperty $From -TargetState $To -State $State -InputObject $CurrentInputObject @ValueOptions
			return
		}

		if ($ResolvedSourceKind -eq 'State' -and $ResolvedTargetKind -eq 'State') {
			if ([string]::Equals($From, $To, [System.StringComparison]::OrdinalIgnoreCase)) {
				Write-Error "Link: Directional State -> State links require distinct endpoints. Source and target were both '$From'." -ErrorAction Continue
				return
			}
			Connect-WPFLinkStateToState -SourceState $From -TargetState $To -State $State @ValueOptions
			return
		}

		Write-Error "Link: Directional mode does not yet support Source=$ResolvedSourceKind and Target=$ResolvedTargetKind."
	}
}
