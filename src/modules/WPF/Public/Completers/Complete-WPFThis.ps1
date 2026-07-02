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
    Completion metadata is discovered via .NET type reflection on the resolved control type.
    PowerShell ETS members (for example Add-Member, Update-TypeData, or TypeData script
    properties applied to instances) are not included in completion results.

    Custom DSL keywords can be mapped to a completion type using Register-WPFCompletionType.

    TODO:
    I needed Copilot to do the heavy lifting on this one. While it works and that's a major accomplishment,
    it doesn't *feel* elegant. I'm not sure if there's a better way to do this, but I should revisit this
    later to see if there's a better way to determine the context.
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

    if (-not $script:WPFThisCompletionCache.Completions.ContainsKey($ControlName)) {
        $Type = Resolve-WPFCompletionType -Name $ControlName
        if (-not $Type) {
            Write-Debug "Failed to resolve WPF type for control '$ControlName'"
            return
        }

        # Method overload formatting for completion tooltips is best when it comes
        # from PSObject members on an object instance, not the [type] literal.
        # Using [Type].PSObject.Members targets RuntimeType methods (for example
        # GetProperty), which do not represent the members available on `$this`.
        $CompletionTarget = $null

        if ($Type -is [type]) {
            try {
                # WARNING: This relies on the control type having a parameterless constructor.
                # If it doesn't, we'll fall back to reflection metadata.
                $CompletionTarget = [Activator]::CreateInstance($Type)
            } catch {
                if ($Type -eq [string]) {
                    $CompletionTarget = [string]::Empty
                } else {
                    Write-Debug "Unable to create completion instance for '$($Type.FullName)'; falling back to reflection member metadata. $($_.Exception.Message)"
                }
            }
        }

        if ($null -ne $CompletionTarget) {
            $Script:WPFThisCompletionCache.Completions[$ControlName] =
                foreach ($Member in $CompletionTarget.PSObject.Members) {
                    switch ($Member.MemberType) {
                        'Property' {
                            [pscustomobject] @{
                                Name = $Member.Name
                                MemberType = 'Property'
                                Definition = "$($Member.TypeNameOfValue) $($Member.Name)"
                            }
                        }
                        'Method' {
                            if ($Member.Name -match '^(get_|set_|add_|remove_)') {
                                continue
                            }

                            [pscustomobject] @{
                                Name = $Member.Name
                                MemberType = 'Method'
                                Definition = @($Member.OverloadDefinitions) -join [Environment]::NewLine
                            }
                        }
                        'Event' {
                            [pscustomobject] @{
                                Name = $Member.Name
                                MemberType = 'Event'
                                Definition = "$($Member.TypeNameOfValue) $($Member.Name)"
                            }
                        }
                    }
                }
        } else {
            $BindingFlags = [System.Reflection.BindingFlags] 'Instance, Public, FlattenHierarchy'

            $PropertyMembers = @(
                $Type.GetProperties($BindingFlags) |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) } |
                    Sort-Object -Unique -Property Name |
                    ForEach-Object {
                        [pscustomobject] @{
                            Name = $_.Name
                            MemberType = 'Property'
                            Definition = "$($_.PropertyType.FullName) $($_.Name)"
                        }
                    }
            )

            $EventMembers = @(
                $Type.GetEvents($BindingFlags) |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) } |
                    Sort-Object -Unique -Property Name |
                    ForEach-Object {
                        [pscustomobject] @{
                            Name = $_.Name
                            MemberType = 'Event'
                            Definition = "$($_.EventHandlerType.FullName) $($_.Name)"
                        }
                    }
            )

            $MethodMembers = @(
                $Type.GetMethods($BindingFlags) |
                    Where-Object {
                        -not $_.IsSpecialName -and
                        -not [string]::IsNullOrWhiteSpace($_.Name)
                    } |
                    Group-Object -Property Name |
                    Sort-Object -Property Name |
                    ForEach-Object {
                        $MethodName = $_.Name
                        $OverloadDefinitions = @(
                            $_.Group |
                                Sort-Object -Property ToString |
                                ForEach-Object { $_.ToString() }
                        )

                        [pscustomobject] @{
                            Name = $MethodName
                            MemberType = 'Method'
                            Definition = ($OverloadDefinitions -join [Environment]::NewLine)
                        }
                    }
            )

            $script:WPFThisCompletionCache.Completions[$ControlName] = @(
                $PropertyMembers + $EventMembers + $MethodMembers
            )
        }
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

    # NOTE: Completion metadata is cached by resolved control name.
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
            # Based on existing behavior in PowerShell, the ToolTip property of a CompletionResult seems
            # to expect a method signature when the CompletionResultType is Method. The signature is
            # auto-converted from C# to Powershell syntax. It is critical that the signature includes
            # the return type, method name, and named parameter list for conversion to work properly.
            # Unfortunately, the lack of an easy way to get said signature makes it difficult. The ones
            # exposed via `MethodInfo.ToString()` lack parameter names.

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
                <# ToolTip #> $CompletionMatch.Definition
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
