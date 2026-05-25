<#
.SYNOPSIS
    Registers or replaces a Chrome adapter for a target control type.

.DESCRIPTION
    Chrome uses adapters to translate style setters into generated template parts.
    Use this helper to register mappings for additional control target types.

.EXAMPLE
    Register-WPFChromeAdapter `
        -TargetType ([System.Windows.Controls.Primitives.ToggleButton]) `
        -ShellType ([System.Windows.Controls.Border]) `
        -PartName 'ToggleChrome' `
        -ShellPropertyMap @{ Background = [System.Windows.Controls.Border]::BackgroundProperty } `
        -ContentPropertyMap @{ Padding = [System.Windows.FrameworkElement]::MarginProperty }
#>
function Register-WPFChromeAdapter {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [type] $TargetType,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [type] $ShellType,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PartName,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [hashtable] $ShellPropertyMap,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [hashtable] $ContentPropertyMap,

        [Parameter()]
        [hashtable] $ContentDefaults = @{},

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Name = $TargetType.Name,

        [switch] $Force
    )

    function Test-ChromeAdapterPropertyMap {
        param(
            [Parameter(Mandatory)]
            [string] $MapName,

            [Parameter(Mandatory)]
            [hashtable] $Map
        )

        foreach ($entry in $Map.GetEnumerator()) {
            if ([string]::IsNullOrWhiteSpace([string] $entry.Key)) {
                Write-Error "Register-WPFChromeAdapter: $MapName contains an empty property name key."
                return $false
            }

            if ($entry.Value -isnot [System.Windows.DependencyProperty]) {
                Write-Error "Register-WPFChromeAdapter: $MapName entry '$($entry.Key)' must be a System.Windows.DependencyProperty."
                return $false
            }
        }

        return $true
    }

    if (-not (Test-ChromeAdapterPropertyMap -MapName 'ShellPropertyMap' -Map $ShellPropertyMap)) {
        return
    }

    if (-not (Test-ChromeAdapterPropertyMap -MapName 'ContentPropertyMap' -Map $ContentPropertyMap)) {
        return
    }

    $contentPropertyNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $ContentPropertyMap.GetEnumerator()) {
        $contentPropertyNames.Add([string] $entry.Key) | Out-Null
    }

    foreach ($entry in $ContentDefaults.GetEnumerator()) {
        if (-not $contentPropertyNames.Contains([string] $entry.Key)) {
            Write-Error "Register-WPFChromeAdapter: ContentDefaults entry '$($entry.Key)' does not exist in ContentPropertyMap."
            return
        }
    }

    $registry = Get-WPFChromeAdapterRegistry -InitializeDefaults
    $adapterKey = $TargetType.AssemblyQualifiedName

    if ($registry.Contains($adapterKey) -and -not $Force) {
        Write-Error "Register-WPFChromeAdapter: An adapter for target type '$($TargetType.FullName)' already exists. Use -Force to replace it."
        return
    }

    $shellMap = [ordered] @{}
    foreach ($entry in $ShellPropertyMap.GetEnumerator()) {
        $shellMap[[string] $entry.Key] = $entry.Value
    }

    $contentMap = [ordered] @{}
    foreach ($entry in $ContentPropertyMap.GetEnumerator()) {
        $contentMap[[string] $entry.Key] = $entry.Value
    }

    $contentDefaultsMap = [ordered] @{}
    foreach ($entry in $ContentDefaults.GetEnumerator()) {
        $contentDefaultsMap[[string] $entry.Key] = $entry.Value
    }

    $adapter = [pscustomobject] @{
        Name = $Name
        TargetType = $TargetType
        ShellType = $ShellType
        PartName = $PartName
        ShellPropertyMap = $shellMap
        ContentPropertyMap = $contentMap
        ContentDefaults = $contentDefaultsMap
    }

    $registry[$adapterKey] = $adapter

    return $adapter
}
