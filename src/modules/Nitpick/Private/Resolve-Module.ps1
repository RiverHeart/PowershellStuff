<#
.SYNOPSIS
    Resolves a PowerShell module by name or PSModuleInfo object, optionally filtering by version.

.DESCRIPTION
    This function attempts to resolve a PowerShell module given either its name as a string or a PSModuleInfo object.
    If a version is specified, it will filter the results to match the requested version.
    If the module is not currently loaded, it will attempt to find it in the list of available modules.

.EXAMPLE
    Resolve the latest version of the "Pester" module that is currently loaded or available.

    Resolve-Module -Module "Pester"

.EXAMPLE
    Resolve Pester version 5.3.0.

    Resolve-Module -Module "Pester" -Version "5.3.0"
#>
function Resolve-Module {
    [CmdletBinding(DefaultParameterSetName='Default')]
    [OutputType([PSModuleInfo])]
    param(
        [Parameter(Mandatory,ParameterSetName='Default',Position=0)]
        [Parameter(Mandatory,ParameterSetName='RequiredVersion',Position=0)]
        [Parameter(Mandatory,ParameterSetName='BoundedVersion',Position=0)]
        [string[]] $Name,

        [Parameter(ParameterSetName='RequiredVersion')]
        [string] $RequiredVersion,

        [Parameter(ParameterSetName='BoundedVersion')]
        [string] $MinimumVersion,

        [Parameter(ParameterSetName='BoundedVersion')]
        [string] $MaximumVersion
    )

    begin {
        # Convert version strings to [version] objects for comparison
        if ($RequiredVersion) { $RequiredVersion = Resolve-Version $RequiredVersion }
        if ($MinimumVersion) { $MinimumVersion = Resolve-Version $MinimumVersion }
        if ($MaximumVersion) { $MaximumVersion = Resolve-Version $MaximumVersion }

        $LoadedModules = Get-Module -All
        $AvailableModules = Get-Module -ListAvailable
    }

    process {
        foreach ($ModuleName in $Name) {
            # Attempt to find the module among the currently loaded modules.
            $MatchingLoadedModules = $LoadedModules |
                Where-Object {
                    $_.Name -eq $ModuleName -and
                    ([string]::IsNullOrEmpty($RequiredVersion) -or $_.Version -eq $RequiredVersion) -and
                    ([string]::IsNullOrEmpty($MinimumVersion) -or $_.Version -ge $MinimumVersion) -and
                    ([string]::IsNullOrEmpty($MaximumVersion) -or $_.Version -le $MaximumVersion)
                } |
                Sort-Object Version -Descending
                Select-Object -First 1

            if ($MatchingLoadedModules) {
                $MatchingLoadedModules |
                    Add-Member -MemberType NoteProperty -Name IsLoaded -Value $true -PassThru |
                    Write-Output
                continue
            }

            # If no loaded matches were found, attempt to find the module among the available modules.
            $AvailableModule = $AvailableModules |
                Where-Object {
                    $_.Name -eq $ModuleName -and
                    ([string]::IsNullOrEmpty($RequiredVersion) -or $_.Version -eq $RequiredVersion) -and
                    ([string]::IsNullOrEmpty($MinimumVersion) -or $_.Version -ge $MinimumVersion) -and
                    ([string]::IsNullOrEmpty($MaximumVersion) -or $_.Version -le $MaximumVersion)
                } |
                Sort-Object Version -Descending |
                Select-Object -First 1

            if ($AvailableModule) {
                $AvailableModule |
                    Add-Member -MemberType NoteProperty -Name IsLoaded -Value $false -PassThru |
                    Write-Output
                continue
            }

            $ErrorMessage = "Module '$ModuleName' was not found."
            $OtherVersions = (
                $AvailableModules |
                Where-Object { $_.Name -eq $ModuleName } |
                ForEach-Object { $_.Version } |
                Select-Object -Unique
            ) -join ", "

            if ($OtherVersions) {
                $ErrorMessage += "`nFound the following versions: $OtherVersions"
            }

            Write-Error $ErrorMessage -Category ObjectNotFound
        }
    }
}
