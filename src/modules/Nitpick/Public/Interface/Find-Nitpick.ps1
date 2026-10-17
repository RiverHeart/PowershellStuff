using namespace System.Management.Automation

<#
.SYNOPSIS
    Acquires Nitpick rule packages, defaulting to the built-in package.

.DESCRIPTION
    Returns identity-bearing NitpickRule descriptors for one or more rule
    packages. With no Module, only the built-in Nitpick package is acquired;
    ambient loaded modules are never scanned.

    Each requested module name or literal path is resolved and acquired as an
    explicit rule package: its declared PrivateData.Linting is read, its
    RuleModules declaration graph is statically validated before anything is
    imported, and the resulting descriptors are stamped with that top-level
    package's namespace. A module with no Linting declaration contributes only
    its own standalone-compatible exported commands.

.PARAMETER Module
    Module names or literal paths to acquire as explicit rule packages.
    Omitted, this acquires only the built-in Nitpick package.

.PARAMETER IncludeRule
    Selects rule IDs (Namespace/Name), such as WPF/AvoidBlockingUI. Supports
    wildcards. Unmatched selectors are silently excluded; this command does
    not validate selectors the way Start-Nitpicking and Register-Nitpick do.

.PARAMETER ExcludeRule
    Excludes matching rule IDs. Supports wildcards.

.EXAMPLE
    Returns all valid Nitpick rules from the built-in package.

    Find-Nitpick

.EXAMPLE
    Acquires an explicit rule package by name or literal path.

    Find-Nitpick -Module WPF

.EXAMPLE
    Pipes the output of Find-Nitpick to Register-Nitpick.

    Find-Nitpick | Register-Nitpick
#>
function Find-Nitpick {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [string[]] $Module = 'Nitpick',

        [string[]] $IncludeRule,
        [string[]] $ExcludeRule
    )

    foreach ($Entry in $Module) {
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
