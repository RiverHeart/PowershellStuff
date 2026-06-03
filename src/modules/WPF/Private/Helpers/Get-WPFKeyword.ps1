<#
.SYNOPSIS
    Finds WPF DSL keyword commands inside a scriptblock.

.DESCRIPTION
    Scans CommandAst nodes in a scriptblock and returns matches for requested keyword
    names. Contextual keywords are validated only when -ParentContext is provided.

    In Strict mode, contextual matches that are invalid for -ParentContext are emitted
    as non-terminating errors and excluded from the output.

.PARAMETER ScriptBlock
    Scriptblock to inspect.

.PARAMETER Name
    Keyword names to search for.

.PARAMETER ParentContext
    Optional parent keyword context (for example, Command or TimedEvent).

.PARAMETER Mode
    Validation mode. Strict validation only applies when -ParentContext is supplied.

.PARAMETER ContextKeywordMap
    Optional parent-to-child contextual keyword map.

.EXAMPLE
    Get-WPFKeyword -ScriptBlock $Block -Name Execute,CanExecute

.EXAMPLE
    Get-WPFKeyword `
        -ScriptBlock $Block `
        -Name Work, OnComplete `
        -ParentContext TimedEvent `
        -Mode Strict
#>
function Get-WPFKeyword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)]
        [scriptblock] $ScriptBlock,

        [Parameter(Mandatory, Position=1)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $ParentContext,

        [Parameter()]
        [ValidateSet('Strict', 'NonStrict')]
        [string] $Mode = 'NonStrict',

        [Parameter()]
        [hashtable] $ContextKeywordMap = @{
            Command    = @('Execute', 'CanExecute', 'BoundTo')
            TimedEvent = @('Work', 'OnComplete')
        }
    )

    $RequestedNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($KeywordName in $Name) {
        if (-not [string]::IsNullOrWhiteSpace($KeywordName)) {
            [void] $RequestedNames.Add($KeywordName)
        }
    }

    if ($RequestedNames.Count -eq 0) {
        return @()
    }

    $ContextualKeywordParents = @{}
    foreach ($Entry in $ContextKeywordMap.GetEnumerator()) {
        $ParentName = [string] $Entry.Key
        foreach ($ChildKeyword in @($Entry.Value)) {
            $ChildName = [string] $ChildKeyword
            if (-not $ContextualKeywordParents.ContainsKey($ChildName)) {
                $ContextualKeywordParents[$ChildName] = [System.Collections.ArrayList]::new()
            }

            if ($ParentName -notin $ContextualKeywordParents[$ChildName]) {
                [void] $ContextualKeywordParents[$ChildName].Add($ParentName)
            }
        }
    }

    $HasParentContext = $PSBoundParameters.ContainsKey('ParentContext') -and -not [string]::IsNullOrWhiteSpace($ParentContext)

    $Matches = Find-AstNode -ScriptBlock $ScriptBlock -Type CommandAst -All -Query {
        $CommandName = $_.GetCommandName()
        if ([string]::IsNullOrWhiteSpace($CommandName)) {
            return $false
        }

        return $RequestedNames.Contains($CommandName)
    }

    foreach ($Match in @($Matches)) {
        $CommandName = [string] $Match.GetCommandName()
        $AllowedParents = @()
        $Kind = 'Primary'
        $ValidationState = 'NotContextual'
        $IsValidInContext = $true

        if ($ContextualKeywordParents.ContainsKey($CommandName)) {
            $Kind = 'Contextual'
            $AllowedParents = @($ContextualKeywordParents[$CommandName])

            if (-not $HasParentContext) {
                $ValidationState = 'ContextRequired'
                $IsValidInContext = $null
            } elseif ($ParentContext -in $AllowedParents) {
                $ValidationState = 'Valid'
                $IsValidInContext = $true
            } else {
                $ValidationState = 'InvalidParentContext'
                $IsValidInContext = $false

                if ($Mode -eq 'Strict') {
                    $ExpectedParents = $AllowedParents -join ', '
                    Write-Error "Contextual keyword '$CommandName' is not valid in parent context '$ParentContext'. Allowed parent contexts: $ExpectedParents."
                    continue
                }
            }
        }

        [pscustomobject] @{
            PSTypeName        = 'WPF.KeywordMatch'
            Name              = $CommandName
            Kind              = $Kind
            ParentContextUsed = if ($HasParentContext) { $ParentContext } else { $null }
            AllowedParents    = $AllowedParents
            IsValidInContext  = $IsValidInContext
            ValidationState   = $ValidationState
            Ast               = $Match
        }
    }
}
