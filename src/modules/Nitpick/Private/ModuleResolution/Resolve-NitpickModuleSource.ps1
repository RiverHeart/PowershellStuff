<#
.SYNOPSIS
    Resolves an explicit module name or literal path to a pinned rule package source.

.DESCRIPTION
    Resolves each requested entry to a module identity, resolved entrypoint path,
    manifest location when available, and an already-loaded instance when one
    exactly matches. Resolution never imports or initializes module code.

    A value that looks path-shaped (a path separator, a provider qualifier, a
    recognized module extension, or an existing filesystem entry) is resolved
    strictly as a literal path and pins that exact source; it is never satisfied
    by an unrelated same-named loaded or available module, and a missing path
    never falls back to name-based resolution.

    A bare module name must match exactly; wildcard patterns are rejected. A
    single already-loaded instance is reused as-is. Multiple loaded instances,
    or multiple distinct available sources tied at the highest version, are
    rejected as ambiguous; an explicit path resolves that ambiguity.

.PARAMETER Module
    One or more module names or literal module paths to resolve.

.EXAMPLE
    Resolve the loaded or highest available version of a module by name.

    Resolve-NitpickModuleSource -Module WPF

.EXAMPLE
    Pin an explicit module manifest path.

    Resolve-NitpickModuleSource -Module .\WPF\WPF.psd1
#>
function Resolve-NitpickModuleSource {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Module
    )

    process {
        foreach ($Entry in $Module) {
            try {
                if (Test-NitpickModulePathShape -Value $Entry) {
                    Resolve-NitpickModulePathSource -Value $Entry
                } else {
                    Resolve-NitpickModuleNameSource -Value $Entry
                }
            } catch {
                Write-Error -ErrorRecord $_
            }
        }
    }
}
