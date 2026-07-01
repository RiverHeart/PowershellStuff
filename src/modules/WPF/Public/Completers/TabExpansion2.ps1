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

    $completions = Complete-WPFThis @PSBoundParameters
    if ($completions) {
        return $completions
    }

    if (Get-Command OriginalTabExpansion2 -ErrorAction SilentlyContinue) {
        return OriginalTabExpansion2 @PSBoundParameters
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
