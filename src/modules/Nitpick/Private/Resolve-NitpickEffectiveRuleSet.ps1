using namespace System.Collections.Generic
using namespace System.Management.Automation

<#
.SYNOPSIS
    Resolves the effective set of Nitpick rules for one Start-Nitpicking invocation.

.DESCRIPTION
    Combines package discovery (via Find-Nitpick) with explicitly registered rules
    (via Get-Nitpick) into one Id-keyed effective rule set. Literal IncludeRule
    selectors must match a known rule Id before exclusions and editor-mode filtering.
    A registered rule's metadata wins over a same-Id discovered candidate, provided
    both share the same underlying callable; a same-Id, different-callable candidate
    terminates resolution before any target is read. At least one eligible rule must
    remain after exclusions and editor-mode filtering.

.PARAMETER Module
    Module names or literal paths to acquire as additive rule packages.

.PARAMETER IncludeRule
    Selects qualified rule IDs. Supports wildcards. Every literal selector must match
    a discovered or registered rule before exclusions and editor-mode filtering.

.PARAMETER ExcludeRule
    Excludes matching rule IDs. Supports wildcards.

.PARAMETER ExcludeDefaults
    Omits the built-in Nitpick package, including when Module is also omitted.

.PARAMETER EditorMode
    Keeps only rules whose EditorEnabled metadata is true.

.EXAMPLE
    Resolve-NitpickEffectiveRuleSet -IncludeRule 'Nitpick/UseIsNotOperator'
#>
function Resolve-NitpickEffectiveRuleSet {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [string[]] $Module,
        [string[]] $IncludeRule,
        [string[]] $ExcludeRule,
        [switch] $ExcludeDefaults,
        [switch] $EditorMode
    )

    $DiscoveredRules = [List[object]]::new()

    Find-Nitpick -Module $Module -IncludeRule $IncludeRule -IncludeDefaults:(-not $ExcludeDefaults) -ErrorAction Stop |
        ForEach-Object { $DiscoveredRules.Add($_) }

    $RegisteredRules = Get-Nitpick
    $KnownRuleIds = [List[string]]::new()
    $DiscoveredRules | ForEach-Object { $KnownRuleIds.Add($_.Id) }
    $RegisteredRules | ForEach-Object { $KnownRuleIds.Add($_.Id) }

    $UnmatchedSelectors = foreach ($Selector in $IncludeRule) {
        if (-not [WildcardPattern]::ContainsWildcardCharacters($Selector) -and
            -not ($KnownRuleIds | Where-Object { $_ -like $Selector })) {
            $Selector
        }
    }
    if ($UnmatchedSelectors.Count -gt 0) {
        throw ((
            "No Nitpick rules match the IncludeRule selector(s): {0}. " +
            "Use qualified rule IDs (for example, Nitpick/UseIsNotOperator, not UseIsNotOperator " +
            "or Test-UseIsNotOperator). Use Find-Nitpick for discovery and Get-Nitpick for registered rules."
        ) -f ($UnmatchedSelectors -join ', '))
    }

    $EffectiveRules = @{}

    $RegisteredRules |
        Where-NitpickIncluded -PropertyPath Id -Include $IncludeRule -Exclude $ExcludeRule -Wildcard |
        ForEach-Object { $EffectiveRules[$_.Id] = $_ }

    $DiscoveredRules |
        Where-NitpickIncluded -PropertyPath Id -Include $IncludeRule -Exclude $ExcludeRule -Wildcard |
        ForEach-Object {
            $Existing = $EffectiveRules[$_.Id]
            if ($Existing) {
                if (-not (Test-NitpickCallableIdentity -Left $Existing.Callable -Right $_.Callable)) {
                    throw "Different Nitpick callables share the rule ID '$($_.Id)'. Exclude the rule or remove the conflicting registration/module."
                }
                return
            }
            $EffectiveRules[$_.Id] = $_
        }

    [object[]] $Rules = @(
        $EffectiveRules.Values | Where-Object { -not $EditorMode -or $_.EditorEnabled }
    )

    if (-not $Rules) {
        if ($KnownRuleIds.Count -eq 0) {
            throw 'No Nitpick rules were discovered or registered. Import a rule module or register a rule before running Start-Nitpicking.'
        }
        throw 'No eligible Nitpick rules remain after applying rule exclusions and editor-mode filtering.'
    }

    return $Rules
}
