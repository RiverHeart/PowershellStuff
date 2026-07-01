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
    any custom controls unless it's added here.
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

    if (-not $script:WPFThisCompletionCache) {
        $script:WPFThisCompletionCache = @{
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

    # NOTE: This isn't going to work for custom controls.
    if (-not $script:WPFThisCompletionCache.Completions.ContainsKey($ControlName)) {
        $Type = @(Get-WPFTypeInfo -Name $ControlName) | Select-Object -First 1
        if (-not $Type) {
            Write-Debug "Failed to resolve WPF type for control '$ControlName'"
            return
        }

        $script:WPFThisCompletionCache.Completions[$ControlName] = @(
            $Type |
                Get-Member |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) } |
                Sort-Object -Unique -Property Name
        )
    }

    $MemberPrefix = $ThisMemberMatch.Groups['member'].Value

    $CompletionMatches = @($script:WPFThisCompletionCache.Completions[$ControlName] |
        Where-Object { $_.Name -ilike "*$MemberPrefix*" } |
        Sort-Object -Property @(
            {
                if ([string]::IsNullOrWhiteSpace($MemberPrefix)) {
                    0
                } else {
                    [int]($_.Name -inotlike "$MemberPrefix*")
                }
            },
            { $_.Name }
        ))

    if ($CompletionMatches.Count -eq 0) {
        return
    }

    $ReplaceIndex = $ThisMemberMatch.Index
    $ReplaceLength = $CursorOffset - $ReplaceIndex
    $CompletionCollection = [System.Collections.ObjectModel.Collection[CompletionResult]]::new()

    # NOTE: This feels a bit heavy. Maybe this should be cached instead of the raw matches?
    # Also, reflections isn't going to give us descriptions for members.
    foreach ($CompletionMatch in $CompletionMatches) {
        $CompletionResultType = switch ($CompletionMatch.MemberType) {
            { $_ -like '*Property' } { [CompletionResultType]::Property }
            { $_ -like '*Method' } { [CompletionResultType]::Method }
            'Event' { [CompletionResultType]::Event }
            default { [CompletionResultType]::None }
        }

        if ($CompletionResultType -eq [CompletionResultType]::None) {
            #Write-Debug "Skipping completion for member '$($CompletionMatch.Name)' of type '$($CompletionMatch.MemberType)'"
            continue
        } elseif ($CompletionResultType -eq [CompletionResultType]::Method) {
            # NOTE:
            # Curious implementation here. It appears as though the ToolTip property is expected to be
            # a method signature when CompletionResult is Method. The signature is auto-converted from C#
            # to Powershell syntax. As an example, here is the auto-converted code for the GetField method.
            #
            # ```
            # using namespace System.Reflection
            #
            # [FieldInfo] GetField(
            #    [string] $name,
            #    [BindingFlags] $bindingAttr)
            #
            # [] System.Reflection.FieldInfo GetField(
            #    [string] $name)
            #
            # [] System.Reflection.FieldInfo IReflect.GetField(
            #    [string] $name,
            #    [BindingFlags] $bindingAttr)
            # ```
            #
            # As you can see, a `using namespace` was added and the return type shortened. Every other signature
            # is converted as well but fails on the return type. It's unclear if this is a bug, expected behavior,
            # or if I'm just passing the wrong object. I tried to figure out where in the Powershell source
            # this conversion is happening but I couldn't find it.
            #
            # One might hope that you could define multiple completions for the same method with different signatures
            # and one would be wrong about that. Duplicate completions produce duplicate menu items. To prevent bloat,
            # we're only adding one instance of each method and passing in the definition list even though it doesn't
            # format properly.

            $CompletionCollection.Add([CompletionResult]::new(
                <# Injected Text #> "`$this.$($CompletionMatch.Name)(",
                <# Menu Text #> "$($CompletionMatch.Name)()",
                <# Icon Type #> $CompletionResultType,
                <# ToolTip #> $CompletionMatch.Definition
            ))
        } else {
            $CompletionCollection.Add([CompletionResult]::new(
                <# Injected Text #> "`$this.$($CompletionMatch.Name)",
                <# Menu Text #> $CompletionMatch.Name,
                <# Icon Type #> $CompletionResultType,
                <# ToolTip #> $CompletionMatch.Name
            ))
        }
    }

    return [CommandCompletion]::new(
        $CompletionCollection,
        0,
        $ReplaceIndex,
        $ReplaceLength
    )
}
