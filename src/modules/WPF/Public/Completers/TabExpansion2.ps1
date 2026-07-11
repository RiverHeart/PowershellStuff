$CommandParams = @{
    CommandType = 'Function'
    ErrorAction = 'SilentlyContinue'
}
if (
    (Get-Command TabExpansion2 @CommandParams) -and
    (-not (Get-Command OriginalTabExpansion2 @CommandParams))
) {
    Copy-Item `
        -Path Function:\global:TabExpansion2 `
        -Destination Function:\script:OriginalTabExpansion2
}

<#
.SYNOPSIS
    Customized TabExpansion2 with WPF DSL support.

.DESCRIPTION
    This function is a wrapper around the built-in TabExpansion2 function and
    is imported when the module is loaded.

    It first attempts to complete WPF DSL script blocks using the `Complete-WPFThis`
    function. If that function returns no completions, it falls back to the
    original TabExpansion2 function.

.NOTES
    Ideally, this function would be updated to support registration of custom
    completers so it doesn't need to be modified every time a new completer
    is required but it is functionally sufficient for now.

.EXAMPLE
    General purpose tab expansion usage

    $Script = ' "Foo". '
    $CursorColumn = $Script.ToString().IndexOf('.') + 1
    TabExpansion2 -inputScript $script -cursorColumn $cursorColumn |
        ForEach-Object { $_.CompletionMatches.CompletionText }

.EXAMPLE
    Auto complete `$this` members inside WPF DSL script blocks.

    $Script = {
        Window 'Main' {
            Button 'SaveButton' {
                $this.Co
            }
        }
    }
    $CursorColumn = $Script.ToString().IndexOf('$this.Co') + 8
    TabExpansion2 -inputScript $script -cursorColumn $cursorColumn |
        ForEach-Object { $_.CompletionMatches.CompletionText }
#>
function TabExpansion2 {
    [CmdletBinding(DefaultParameterSetName = 'ScriptInputSet')]
    [OutputType([System.Management.Automation.CommandCompletion])]
    param(
        [Parameter(ParameterSetName = 'ScriptInputSet', Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [string] $inputScript,

        [Parameter(ParameterSetName = 'ScriptInputSet', Position = 1)]
        [int] $cursorColumn = $inputScript.Length,

        [Parameter(ParameterSetName = 'AstInputSet', Mandatory = $true, Position = 0)]
        [System.Management.Automation.Language.Ast] $ast,

        [Parameter(ParameterSetName = 'AstInputSet', Mandatory = $true, Position = 1)]
        [System.Management.Automation.Language.Token[]] $tokens,

        [Parameter(ParameterSetName = 'AstInputSet', Mandatory = $true, Position = 2)]
        [System.Management.Automation.Language.IScriptPosition] $positionOfCursor,

        [Parameter(ParameterSetName = 'ScriptInputSet', Position = 2)]
        [Parameter(ParameterSetName = 'AstInputSet', Position = 3)]
        [Hashtable] $options = $null
    )

    $Completions = $null

    # Create a registry to hold custom tab completers and result modifiers. This allows us to
    # register new completers and modifiers without having to modify this function every time.
    if (-not $global:TabExpansionRegistry) {
        $global:TabExpansionRegistry = @{
            TabCompleters = @{}
            ResultModifiers = @{}
        }
    }

    #-------------------------
    # Custom Tab Completers
    #-------------------------

    try {
        $TabCompleters = $global:TabExpansionRegistry.TabCompleters.GetEnumerator()
        $Completions = $TabCompleters |
            ForEach-Object {
                & $_.Value @PSBoundParameters
            } |
            Where-Object { $_ -is [System.Management.Automation.CommandCompletion] } |
            Select-Object -First 1

        if ($Completions) {
            Write-Debug 'Using custom tab completer result.'
        }
    } catch {
        Write-Debug "Complete-WPFThis failed during tab expansion: $($_.Exception.Message)"
    }

    #--------------------------
    # Original TabExpansion2
    #--------------------------

    if (-not $Completions) {
        if (Get-Command OriginalTabExpansion2 -ErrorAction SilentlyContinue) {
            #Write-Host "Falling back to OriginalTabExpansion2"
            $Completions = OriginalTabExpansion2 @PSBoundParameters
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

    #--------------------------
    # Result Modifiers
    #--------------------------

    if ($global:TabExpansionRegistry.ResultModifiers.Count -gt 0) {
        try {
            foreach ($ResultModifier in $global:TabExpansionRegistry.ResultModifiers.GetEnumerator()) {
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

    #Write-Host "Returning $($Completions.Count) completions"
    return $Completions
}
