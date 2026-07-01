using namespace System
using namespace System.Collections
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Provides auto-complete for `$this` property names inside WPF script blocks.

.DESCRIPTION
    Provides auto-complete for `$this` property names inside WPF script blocks.

    Because this is being called from TabExpansion2, we're forwarding the same parameters to this function.
    The `$this` variable is only available inside script blocks, so we need to determine the context of the
    cursor to determine if we're inside a script block and what control the script block belongs to. We also
    need to know if the user is typing a property name after `$this.` to provide the correct completions or
    back out if not.

.NOTES
    TODO:
    I needed Copilot to do the heavy lifting on this one. While it works and that's a major accomplishment,
    it doesn't *feel* elegant. I'm not sure if there's a better way to do this, but I should revisit this
    later to see if there's a better way to determine the context. The way it is now it's going to fail for
    any custom controls unless it's added here. Additionally, auto-complete is limited to properties but
    we should be including methods and events as well.
#>
function Complete-WPFThis {
    [CmdletBinding()]
    [OutputType([CommandCompletion])]
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

    if (-not $script:WPFControlPropertiesCache) {
        $script:WPFControlPropertiesCache = @{
            Completions = @{}
        }
    }

    $CursorOffset = $null
    if ($PSCmdlet.ParameterSetName -eq 'ScriptInputSet') {
        $CursorOffset = [Math]::Max(0, [Math]::Min($cursorColumn, $inputScript.Length))
    } else {
        $inputScript = $ast.Extent.Text
        if (-not $positionOfCursor -or $null -eq $positionOfCursor.Offset) {
            return
        }

        $CursorOffset = [Math]::Max(0, [Math]::Min([int] $positionOfCursor.Offset, $inputScript.Length))
    }

    # Restrict the input we're analyzing to the script up to the cursor position.
    # We need to know if the user is actually typing a property name after `$this.`
    # and not a false positive like `$this.Foo` on a separate line.
    $scriptUpToCursor = $inputScript.Substring(0, $CursorOffset)

    $ThisMemberMatch = [Regex]::Match($scriptUpToCursor, '(?is)\$this\.(?<member>[A-Za-z_][A-Za-z0-9_]*)?$')
    if (-not $ThisMemberMatch.Success) {
        return
    }

    if ($PSCmdlet.ParameterSetName -eq 'ScriptInputSet') {
        $tokens = $null
        $parseErrors = $null
        $ast = [Parser]::ParseInput($inputScript, [ref] $tokens, [ref] $parseErrors)
    }

    $ParentControlNode = Resolve-WPFControlCommandAstAtCursor -Ast $ast -CursorOffset $CursorOffset
    if (-not $ParentControlNode) {
        return
    }

    $ControlName = $ParentControlNode.GetCommandName()
    if ([string]::IsNullOrWhiteSpace($ControlName)) {
        return
    }

    if ($ControlName -ieq 'App') {
        $ControlName = 'Window'
    }

    if (-not $script:WPFControlPropertiesCache.Completions.ContainsKey($ControlName)) {
        $Type = @(Get-WPFTypeInfo -Name $ControlName) | Select-Object -First 1
        if (-not $Type) {
            Write-Debug "Failed to resolve WPF type for control '$ControlName'"
            return
        }

        $script:WPFControlPropertiesCache.Completions[$ControlName] = @(
            $Type.GetProperties().Name |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Sort-Object -Unique
        )
    }

    $MemberPrefix = $ThisMemberMatch.Groups['member'].Value

    $PropertyMatches = @($script:WPFControlPropertiesCache.Completions[$ControlName] |
        Where-Object { $_ -ilike "*$MemberPrefix*" } |
        Sort-Object -Property @(
            {
                if ([string]::IsNullOrWhiteSpace($MemberPrefix)) {
                    0
                } else {
                    [int]($_ -inotlike "$MemberPrefix*")
                }
            },
            { $_ }
        ))

    if ($PropertyMatches.Count -eq 0) {
        return
    }

    $ReplaceIndex = $ThisMemberMatch.Index
    $ReplaceLength = $CursorOffset - $ReplaceIndex
    $CompletionCollection = [System.Collections.ObjectModel.Collection[CompletionResult]]::new()

    foreach ($PropertyName in $PropertyMatches) {
        $CompletionCollection.Add([CompletionResult]::new(
                "`$this.$PropertyName",
                $PropertyName,
                [CompletionResultType]::Property,
                "$ControlName Property"
            ))
    }

    return [CommandCompletion]::new(
        $CompletionCollection,
        0,
        $ReplaceIndex,
        $ReplaceLength
    )
}
