<#
.SYNOPSIS
    Customized TabExpansion2 with support for TabCentral hooks.

.DESCRIPTION
    This function is a wrapper around the active TabExpansion2 implementation.
    When TabCentral is enabled, it first attempts to complete tab expansion
    using registered TabCentral hooks. If no custom completion is produced,
    it falls back to the original behavior.

.EXAMPLE
    General purpose tab expansion usage

    $Script = ' "Foo". '
    $CursorColumn = $Script.ToString().IndexOf('.') + 1
    TabExpansion2 -inputScript $Script -cursorColumn $CursorColumn |
        ForEach-Object { $_.CompletionMatches.CompletionText }
#>
function TabExpansion2 {
    [CmdletBinding(DefaultParameterSetName = 'ScriptInputSet')]
    [OutputType([System.Management.Automation.CommandCompletion])]
    param(
        [Parameter(ParameterSetName = 'ScriptInputSet', Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string] $inputScript,

        [Parameter(ParameterSetName = 'ScriptInputSet', Position = 1)]
        [int] $cursorColumn = $inputScript.Length,

        [Parameter(ParameterSetName = 'AstInputSet', Mandatory, Position = 0)]
        [System.Management.Automation.Language.Ast] $ast,

        [Parameter(ParameterSetName = 'AstInputSet', Mandatory, Position = 1)]
        [System.Management.Automation.Language.Token[]] $tokens,

        [Parameter(ParameterSetName = 'AstInputSet', Mandatory, Position = 2)]
        [System.Management.Automation.Language.IScriptPosition] $positionOfCursor,

        [Parameter(ParameterSetName = 'ScriptInputSet', Position = 2)]
        [Parameter(ParameterSetName = 'AstInputSet', Position = 3)]
        [Hashtable] $options = $null
    )

    # Preserve standard shell behavior unless explicitly enabled.
    if (-not $global:TabCentralEnabled) {
        if ($script:OriginalTabExpansion2) {
            return (& $script:OriginalTabExpansion2 @PSBoundParameters)
        }

        if ($PSCmdlet.ParameterSetName -eq 'ScriptInputSet') {
            return [System.Management.Automation.CommandCompletion]::CompleteInput(
                $inputScript,
                $cursorColumn,
                $options
            )
        }

        return [System.Management.Automation.CommandCompletion]::CompleteInput(
            $ast,
            $tokens,
            $positionOfCursor,
            $options
        )
    }

    $Completions = $null
    $Registry = Get-TabCentralRegistry

    try {
        $TabCompleters = $Registry.TabCompleters.GetEnumerator()
        $Completions = $TabCompleters |
            ForEach-Object {
                & $_.Value @PSBoundParameters
            } |
            Where-Object { $_ -is [System.Management.Automation.CommandCompletion] } |
            Select-Object -First 1
    } catch {
        Write-Debug "Custom TabCentral hook failed during tab expansion: $($_.Exception.Message)"
    }

    if (-not $Completions) {
        if ($script:OriginalTabExpansion2) {
            $Completions = & $script:OriginalTabExpansion2 @PSBoundParameters
        } elseif ($PSCmdlet.ParameterSetName -eq 'ScriptInputSet') {
            $Completions = [System.Management.Automation.CommandCompletion]::CompleteInput(
                $inputScript,
                $cursorColumn,
                $options
            )
        } else {
            $Completions = [System.Management.Automation.CommandCompletion]::CompleteInput(
                $ast,
                $tokens,
                $positionOfCursor,
                $options
            )
        }
    }

    if ($Registry.ResultModifiers.Count -gt 0) {
        try {
            foreach ($ResultModifier in $Registry.ResultModifiers.GetEnumerator()) {
                $ModifiedCompletions = @(
                    & $ResultModifier.Value -CommandCompletion $Completions
                )

                if (($ModifiedCompletions.Count -eq 1) -and ($ModifiedCompletions[0] -is [System.Management.Automation.CommandCompletion])) {
                    $Completions = $ModifiedCompletions[0]
                }
            }
        } catch {
            Write-Debug "Result modifier failed during tab expansion: $($_.Exception.Message)"
        }
    }

    return $Completions
}
