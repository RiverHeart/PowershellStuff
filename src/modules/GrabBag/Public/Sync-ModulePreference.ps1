<#
.SYNOPSIS
    Synchronizes the session state of the callee with the session
    state of the caller.

.DESCRIPTION
    Synchronizes the session state of the callee with the session
    state of the caller.

    In effect, this means that preference variables set in the caller
    are passed onto the callee.

.EXAMPLE
    Update modules on import

    Import-Module Pester -PassThru | Sync-ModulePreference -Verbose

.EXAMPLE
    Sync preferences with an already loaded module.

    # Define an in-memory module with a single function Foo() that provokes
    # a non-terminating error.
    $Mod = New-Module {
        function Foo {
            [CmdletBinding()] param()
            Write-Host "NoNewLine"
            Write-Verbose "Foo"

            # Provoke a non-terminating error.
            Get-Item /Nosuch

            Write-Host "Never getting here"
        }
    }

    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'
    if (-not $PSDefaultParameterValues.ContainsKey('Write-Host:NoNewLine')) {
        $PSDefaultParameterValues.Add('Write-Host:NoNewLine', $True)
    }

    Sync-ModulePreference `
        -Verbose `
        -InputObject $Mod `
        -Include @('ErrorActionPreference', 'VerbosePreference', 'PSDefaultParameterValues', 'ConfirmPreference') `
        -Exclude ('ConfirmPreference')

    Foo
#>
function Sync-ModulePreference {
    [CmdletBinding(DefaultParameterSetName='Names')]
    param(
        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName='Names')]
        [ValidateNotNullOrEmpty()]
        [string[]] $Name,

        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName='Objects')]
        [System.Management.Automation.PSModuleInfo[]] $InputObject,

        [ValidateNotNull()]
        [System.Management.Automation.SessionState] $SessionState = $PScmdlet.SessionState,

        [Parameter(HelpMessage='Subset of preferences to sync')]
        [string[]] $Include,

        [Parameter(HelpMessage='Subset of preferences to exclude from sync')]
        [string[]] $Exclude
    )

    begin {
        $Preferences = @(
            'ConfirmPreference',        'DebugPreference',               'ErrorActionPreference',
            'ErrorView',                'FormatEnumerationLimit',        'InformationPreference',
            'LogCommandHealthEvent',    'LogCommandLifecycleEvent',      'LogEngineHealthEvent',
            'LogEngineLifecycleEvent',  'LogProviderHealthEvent',        'LogProviderLifecycleEvent',
            'MaximumHistoryCount',      'OFS',                           'OutputEncoding',
            'ProgressPreference',       'PSDefaultParameterValues',      'PSEmailServer',
            'PSModuleAutoloadingPreference', 'PSSessionApplicationName', 'PSSessionConfigurationName',
            'PSSessionOption',          'VerbosePreference',             'WarningPreference',
            'WhatIfPreference'
        )
        if ($PSEdition -eq 'Core') {
            $Preferences += @(
                'PSNativeCommandUseErrorActionPreference', 'PSNativeCommandArgumentPassing', 'PSStyle'
            )
        }
        $Preferences = $Preferences |
            Where-Object {
                $IsIncluded = if ($Include) { $_ -in $Include } else { $True }
                $IsExcluded = if ($Exclude) { $_ -in $Exclude } else { $False }
                $IsIncluded -and -not $IsExcluded
            }
    }

    process {
        $Modules = if ($PSCmdlet.ParameterSetName -eq 'Names') { Get-Module $Name } else { $InputObject }

        foreach($Module in $Modules) {
            Write-Verbose "Updating Module '$Module'"
            foreach ($Preference in $Preferences) {
                $CallerVar = $SessionState.PSVariable.Get($Preference)
                if ($null -eq $CallerVar) {
                    Write-Verbose "Preference '$Preference' not found in caller's scope."
                    continue
                }
                $CallerValue = $CallerVar.Value
                $ModuleValue = $Module.SessionState.PSVariable.GetValue($Preference)

                if ($CallerValue -is [Hashtable]) {
                    foreach ($CallPair in $CallerValue.GetEnumerator()) {
                        $ModPairValue = if ($ModuleValue.($CallPair.Name)) { $ModuleValue.($CallPair.Name) }

                        if ($CallPair.Value -ne $ModPairValue) {
                            Write-Verbose "Updating Preference '$Preference.$($CallPair.Name)' from '$ModPairValue' to '$($CallPair.Value)'"
                            $ModuleValue[$CallPair.Name] = $CallPair.Value
                        }
                    }
                } elseif ($CallerValue -ne $ModuleValue) {
                    Write-Verbose "Updating Preference '$Preference' from '$ModuleValue' to '$CallerValue'"
                    $Module.SessionState.PSVariable.Set("Script:$Preference", $CallerValue)
                }
            }
        }
    }
}
