using namespace System.Management.Automation

<#
.SYNOPSIS
    Acquires Nitpick rule packages, defaulting to the built-in package.

.DESCRIPTION
    Returns identity-bearing NitpickRule descriptors for one or more rule
    packages. With no Module, only the built-in Nitpick package is acquired.
    Specifying Module acquires only the requested package(s), replacing the
    built-in default, unless IncludeDefaults is also specified to acquire both
    together. Ambient loaded modules are never scanned.

    Each requested module name or literal path is resolved and acquired as an
    explicit rule package: its declared PrivateData.Linting is read, its
    RuleModules declaration graph is statically validated before anything is
    imported, and the resulting descriptors are stamped with their owning
    module's namespace. Supporting modules declare that owner with
    PrivateData.Linting.OwnerModule and must be listed by the owner in
    RuleModules. A module with no Linting declaration contributes only its
    own standalone-compatible exported commands.

.PARAMETER Module
    Module names or literal paths to acquire as explicit rule packages.
    Omitted, this acquires only the built-in Nitpick package.

.PARAMETER IncludeRule
    Selects rule IDs (Namespace/Name), such as WPF/AvoidBlockingUI. Supports
    wildcards. Unmatched selectors are silently excluded; this command does
    not validate selectors the way Start-Nitpicking and Register-Nitpick do.

.PARAMETER ExcludeRule
    Excludes matching rule IDs. Supports wildcards.

.PARAMETER IncludeDefaults
    Also acquires the built-in Nitpick package alongside explicitly requested
    Module entries, instead of Module replacing it. Has no effect on its own
    (the built-in package is already acquired) when Module is omitted; pass
    -IncludeDefaults:$false with no Module to acquire nothing instead.

.EXAMPLE
    Returns all valid Nitpick rules from the built-in package.

    Find-Nitpick

.EXAMPLE
    Acquires only the explicitly requested rule package, replacing the
    built-in default.

    Find-Nitpick -Module WPF

.EXAMPLE
    Acquires an explicit rule package additively with the built-in package.

    Find-Nitpick -Module WPF -IncludeDefaults

.EXAMPLE
    Pipes the output of Find-Nitpick to Register-Nitpick.

    Find-Nitpick | Register-Nitpick
#>
function Find-Nitpick {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [string[]] $Module,
        [string[]] $IncludeRule,
        [string[]] $ExcludeRule,
        [switch] $IncludeDefaults
    )

    $ShouldIncludeDefaults = if ($PSBoundParameters.ContainsKey('IncludeDefaults')) {
        [bool] $IncludeDefaults
    } else {
        -not $Module
    }

    $Modules = @()
    $Modules += $Module
    if ($ShouldIncludeDefaults) { $Modules += 'Nitpick' }
    $Modules = $Modules | Select-Object -Unique

    foreach ($Entry in $Modules) {
        try {
            $PackageRules = Get-NitpickPackage -Module $Entry -ErrorAction Stop
        } catch {
            Write-Error -ErrorRecord $_
            continue
        }

        $PackageRules |
            Where-NitpickIncluded -PropertyPath Id -Include $IncludeRule -Exclude $ExcludeRule -Wildcard
    }
}
