<#
.SYNOPSIS
    DSL keyword for importing script files into the caller's scope.

.DESCRIPTION
    Import resolves a file path glob and dot-sources each matching file
    into the caller's scope. This is useful for organizing larger projects
    into multiple files while still allowing them to share functions and variables.

.NOTES
    This is probably inefficient and not something you want to be doing but it
    allows splitting up a project without going into module territory and it
    fits the DSL style of doing things so here we are.

.PARAMETER Path
    File path or glob pattern to import. Supports wildcards like .\Functions\*.ps1.

.EXAMPLE
    Import .\Functions\*.ps1

.EXAMPLE
    Import .\Functions\Public\*.ps1
#>
function Import {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    process {
        $Files = Get-ChildItem -Path $Path -File |
            Where-Object { $_.Extension -in @('.ps1', '.psd1') }

        foreach ($File in $Files) {
            Write-Host "Importing: $($File.FullName)"
            $ExecutionContext.InvokeCommand.InvokeScript(
                <# UseLocalScope #> $PSCmdlet.SessionState,
                <# string script #> [scriptblock]::Create(". '$($File.FullName)'"),
                <# IList input #> $null,
                <# Params System.Object[] args #> $null
            )
        }
    }
}
