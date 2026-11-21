using namespace System.Collections

<#
.SYNOPSIS
    Validates the shared syntax-policy schema and normalizes its release version.

.DESCRIPTION
    Empty containers mean no requirement. Configuration uses exact release
    strings; direct context may also use a two-component System.Version.

.EXAMPLE
    Normalize the declared minimum to a two-component System.Version.

    $NitpickModule = Import-Module Nitpick -PassThru
    $NitpickModule.NewBoundScriptBlock({
        $Policy = ConvertTo-NitpickPolicy -Policy @{
            Compatibility = @{
                PowerShell = @{ MinimumVersion = '5.1' }
            }
        }
        $Policy.Compatibility.PowerShell.MinimumVersion
    }).Invoke()

.EXAMPLE
    Accept an already typed minimum from direct invocation context. Without
    AllowVersion, minimum versions must be supported release strings.

    $NitpickModule = Import-Module Nitpick -PassThru
    $NitpickModule.NewBoundScriptBlock({
        $Policy = ConvertTo-NitpickPolicy -AllowVersion -Policy @{
            Compatibility = @{
                PowerShell = @{ MinimumVersion = [version] '7.4' }
            }
        }
    }).Invoke()

.NOTES
    Private helper; examples run within Nitpick's module scope.
#>
function ConvertTo-NitpickPolicy {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [AllowNull()]
        [object] $Policy,

        [switch] $AllowVersion
    )

    $SupportedVersions = @(
        '5.1',
        '6.0', '6.1', '6.2',
        '7.0', '7.1', '7.2', '7.3', '7.4', '7.5', '7.6'
    )
    $Container = $Policy
    $Path = 'Policy'

    foreach ($Level in @(
        @{ Key = 'Compatibility' },
        @{ Key = 'PowerShell' },
        @{ Key = 'MinimumVersion' }
    )) {
        if ($Container -isnot [IDictionary]) {
            throw [ArgumentException]::new("'$Path' must be a string-keyed dictionary.")
        }

        foreach ($Key in $Container.psbase.Keys) {
            if ($Key -isnot [string] -or $Key -ine $Level.Key) {
                throw [ArgumentException]::new("Unknown policy key '$Path.$Key'.")
            }
        }

        if (-not $Container.Contains($Level.Key)) { return @{} }

        $Container = $Container[$Level.Key]
        $Path += ".$($Level.Key)"
    }

    if ($AllowVersion -and $Container -is [version] -and
        $Container.Build -eq -1 -and
        $Container.Revision -eq -1
    ) {
        $Container = $Container.ToString()
    }

    if ($Container -isnot [string] -or $SupportedVersions -cnotcontains $Container) {
        throw [ArgumentException]::new(
            "'$Path' must be a supported major/minor release: $($SupportedVersions -join ', ')."
        )
    }

    return @{
        Compatibility = @{
            PowerShell = @{
                MinimumVersion = [version]::new($Container)
            }
        }
    }
}
