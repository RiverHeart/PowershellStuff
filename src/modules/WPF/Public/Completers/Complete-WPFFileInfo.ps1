using namespace System
using namespace System.Collections
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

function Complete-WPFFileInfo {
    [CmdletBinding()]
    [OutputType([CompletionResult[]])]
    param(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [CommandAst] $CommandAst,
        [IDictionary] $FakeBoundParameters,
        [switch] $Type,
        [switch] $Category
    )

    # Load FileInfo objects
    # Useful for providing autocomplete to Get-WPFFileInfo
    # when testing outside of the module
    if (-not $Script:WPFFileInfo) {
        $Script:WPFFileInfo = Import-PowerShellDataFile -Path "$PSScriptRoot/../../Private/Data/FileInfo.psd1"
    }

    # Detect if word is quoted. Strip quotes for filtering
    # and add to results returned.
    $Quote = [Regex]::Match($WordToComplete, "^('|`")").Value
    if ($Quote) {
        $WordToComplete = $WordToComplete.Trim($Quote)
    }

    if ($Type) {
        $PossibleCompletions = $Script:WPFFileInfo.FileInfo.GetEnumerator()
    } elseif ($Category) {
        $PossibleCompletions = $Script:WPFFileInfo.Categories.GetEnumerator()
    } else {
        return $null
    }

    $Completions = $PossibleCompletions |
        Where-Object {
            $_.Key.StartsWith($WordToComplete, [StringComparison]::InvariantCultureIgnoreCase)
        } |
        Sort-Object -Property $_.Key |
        ForEach-Object {
            $CompletionText = if ($Quote) { $Quote + $_.Key + $Quote  } else { $_.Key }
            [CompletionResult]::new(
                <# Text to insert #> $CompletionText,
                <# Text displayed in the list #> $_.Key,
                <# Result type #> [CompletionResultType]::ParameterValue,
                <# Tooltip #> $_.Value.Description
            )
        }

    if ($Completions.Count -gt 0) {
        return $Completions
    }
    return $null  # Prevent fallback autocomplete
}
