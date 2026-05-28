using namespace System.Collections.Generic
using namespace System.Text.RegularExpressions

<#
.SYNOPSIS
    Applies structured bulk text replacements across files.

.DESCRIPTION
    Invoke-BulkReplace resolves target files from one or more paths, applies one or more
    replacement rules in order, and writes only the files that actually change.
    Use -WhatIf to preview, -PassThru to inspect reports, and explicit rules to keep
    replacements auditable and repeatable.

.PARAMETER Path
    One or more file or directory paths to scan.

.PARAMETER Rule
    One or more replacement rules. Each rule must define Pattern and, in replace mode,
    Replacement. Optional keys are Name, Regex, FirstOnly, IgnoreCase, and FilePattern.

.PARAMETER RulePath
    Path to a JSON or PSD1 file containing replacement rules.

.PARAMETER Find
    Convenience pattern for single-rule usage when you do not want to build a full Rule object.

.PARAMETER Replace
    Convenience replacement text for single-rule usage with Find.

.PARAMETER UseRegex
    Marks the convenience Find/Replace rule as regex-based.

.PARAMETER FirstOnly
    Apply only the first match for the convenience Find/Replace rule.

.PARAMETER IgnoreCase
    Apply case-insensitive matching for the convenience Find/Replace rule.

.PARAMETER FilePattern
    Optional file glob pattern(s) for the convenience Find/Replace rule.

.PARAMETER Include
    File name glob patterns to include when a directory is scanned.

.PARAMETER Exclude
    File name glob patterns to exclude when a directory is scanned.

.PARAMETER Recurse
    Scan subdirectories when a directory is supplied.

.PARAMETER PassThru
    Return a report for each file that matched at least one replacement rule, including line-numbered
    change details suitable for review or feeding into file-editing workflows.

.PARAMETER PassThruFormat
    Selects pass-through verbosity. Summary returns compact objects. Detailed includes line-level changes.

.PARAMETER SearchOnly
    Search for matching lines and return line-numbered hits without writing changes.

.EXAMPLE
    Search Only (compact output)

    ./Invoke-BulkReplace.ps1 `
        -Path 'src/modules/WPF/Tests' `
        -Recurse `
        -Include '*.Tests.ps1' `
        -SearchOnly `
        -Find "Describe '([^']+)' \{" `
        -UseRegex `
        -PassThru

.EXAMPLE
    Search Only (line-level details)

    ./Invoke-BulkReplace.ps1 `
        -Path 'src/modules/WPF/Tests/BindProperty.Tests.ps1' `
        -SearchOnly `
        -Find "Describe 'BindProperty'" `
        -PassThru `
        -PassThruFormat Detailed

.EXAMPLE
    Preview replacement with WhatIf

    ./Invoke-BulkReplace.ps1 `
        -Path 'src/modules/WPF/Tests/BindProperty.Tests.ps1' `
        -Find "Describe 'BindProperty' {" `
        -Replace "Describe 'BindProperty' -Tag 'BindProperty' {" `
        -WhatIf `
        -PassThru

.EXAMPLE
    Apply replacement

    ./Invoke-BulkReplace.ps1 `
        -Path 'src/modules/WPF/Tests/BindProperty.Tests.ps1' `
        -Find "Describe 'BindProperty' {" `
        -Replace "Describe 'BindProperty' -Tag 'BindProperty' {" `
        -PassThru

.EXAMPLE
    Load rules from a file

    ./Invoke-BulkReplace.ps1 `
        -Path 'src/modules/WPF/Tests' `
        -Recurse `
        -Include '*.Tests.ps1' `
        -RulePath './src/modules/WPF/Scripts/rules/tagging.json' `
        -WhatIf `
        -PassThru

.EXAMPLE
    Regex capture replacement (generic pattern rewrite)

    ./Invoke-BulkReplace.ps1 `
        -Path 'src/modules/WPF/Tests' `
        -Recurse `
        -Include '*.Tests.ps1' `
        -Find "^Describe '([^']+)' \{$" `
        -Replace "Describe '$1' -Tag '$1' {" `
        -UseRegex `
        -WhatIf `
        -PassThru `
        -PassThruFormat Detailed
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]

param (
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string[]] $Path,

    [Parameter(Position = 1)]
    [object[]] $Rule,

    [string] $RulePath,

    [string] $Find,

    [string] $Replace,

    [switch] $UseRegex,

    [switch] $FirstOnly,

    [switch] $IgnoreCase,

    [string[]] $FilePattern,

    [string[]] $Include = @('*.ps1', '*.psm1', '*.psd1'),

    [string[]] $Exclude = @(),

    [switch] $Recurse,

    [switch] $SearchOnly,

    [switch] $PassThru,

    [ValidateSet('Summary', 'Detailed')]
    [string] $PassThruFormat = 'Summary'
)

function ConvertTo-BulkReplaceRule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object] $InputRule,

        [Parameter(Mandatory)]
        [int] $Index,

        [switch] $SearchOnly
    )

    $ruleObject = if ($InputRule -is [hashtable]) {
        [pscustomobject] $InputRule
    } else {
        $InputRule
    }

    if ($null -eq $ruleObject) {
        throw "Rule $Index is null."
    }

    if (-not ($ruleObject.PSObject.Properties.Name -contains 'Pattern') -or [string]::IsNullOrWhiteSpace([string] $ruleObject.Pattern)) {
        throw "Rule $Index must define a non-empty Pattern value."
    }

    if (-not $SearchOnly) {
        if (-not ($ruleObject.PSObject.Properties.Name -contains 'Replacement') -or [string]::IsNullOrWhiteSpace([string] $ruleObject.Replacement)) {
            throw "Rule $Index must define a non-empty Replacement value."
        }
    }

    $ruleName = if ($ruleObject.PSObject.Properties.Name -contains 'Name' -and -not [string]::IsNullOrWhiteSpace([string] $ruleObject.Name)) {
        [string] $ruleObject.Name
    } else {
        "Rule $Index"
    }

    $filePattern = @()
    if ($ruleObject.PSObject.Properties.Name -contains 'FilePattern' -and $null -ne $ruleObject.FilePattern) {
        $filePattern = @($ruleObject.FilePattern | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) })
    }

    [pscustomobject]@{
        Name        = $ruleName
        Pattern     = [string] $ruleObject.Pattern
        Replacement = if ($SearchOnly) { $null } else { [string] $ruleObject.Replacement }
        Regex       = ($ruleObject.PSObject.Properties.Name -contains 'Regex' -and [bool] $ruleObject.Regex)
        FirstOnly   = ($ruleObject.PSObject.Properties.Name -contains 'FirstOnly' -and [bool] $ruleObject.FirstOnly)
        IgnoreCase  = ($ruleObject.PSObject.Properties.Name -contains 'IgnoreCase' -and [bool] $ruleObject.IgnoreCase)
        FilePattern = $filePattern
    }
}

function Read-BulkReplaceRuleFile {
    [CmdletBinding()]
    [OutputType([object[]])]
    param (
        [Parameter(Mandatory)]
        [string] $Path
    )

    $resolvedPath = (Resolve-Path -Path $Path -ErrorAction Stop).Path
    $extension = [System.IO.Path]::GetExtension($resolvedPath)

    if ($extension -ieq '.json') {
        $content = Get-Content -Path $resolvedPath -Raw -ErrorAction Stop
        $parsed = ConvertFrom-Json -InputObject $content -ErrorAction Stop
    } elseif ($extension -ieq '.psd1') {
        $parsed = Import-PowerShellDataFile -Path $resolvedPath -ErrorAction Stop
    } else {
        throw "Unsupported rule file extension '$extension'. Use .json or .psd1."
    }

    if ($parsed -is [hashtable] -and $parsed.ContainsKey('Rule')) {
        return @($parsed.Rule)
    }

    return @($parsed)
}

function Resolve-BulkReplaceRuleInput {
    [CmdletBinding()]
    [OutputType([object[]])]
    param (
        [Parameter()]
        [object[]] $Rule,

        [string] $RulePath,

        [string] $Find,

        [string] $Replace,

        [switch] $UseRegex,

        [switch] $FirstOnly,

        [switch] $IgnoreCase,

        [string[]] $FilePattern,

        [switch] $SearchOnly
    )

    $sources = @(
        if ($null -ne $Rule -and @($Rule).Count -gt 0) { 'Rule' }
        if (-not [string]::IsNullOrWhiteSpace($RulePath)) { 'RulePath' }
        if (-not [string]::IsNullOrWhiteSpace($Find) -or -not [string]::IsNullOrWhiteSpace($Replace)) { 'FindReplace' }
    )

    if ($sources.Count -eq 0) {
        throw 'Supply replacement rules via -Rule, -RulePath, or -Find/-Replace.'
    }

    if ($sources.Count -gt 1) {
        throw "Specify only one rule source. Found: $($sources -join ', ')."
    }

    if ($sources[0] -eq 'Rule') {
        return @($Rule)
    }

    if ($sources[0] -eq 'RulePath') {
        return @(Read-BulkReplaceRuleFile -Path $RulePath)
    }

    if ([string]::IsNullOrWhiteSpace($Find)) {
        throw 'Find/Replace mode requires -Find.'
    }

    if (-not $SearchOnly -and [string]::IsNullOrWhiteSpace($Replace)) {
        throw 'Find/Replace mode requires -Replace unless -SearchOnly is used.'
    }

    return @(
        [pscustomobject]@{
            Name        = 'FindReplace'
            Pattern     = $Find
            Replacement = $Replace
            Regex       = [bool] $UseRegex
            FirstOnly   = [bool] $FirstOnly
            IgnoreCase  = [bool] $IgnoreCase
            FilePattern = $FilePattern
        }
    )
}

function Test-BulkReplaceFilePattern {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $FilePath,

        [Parameter()]
        [string[]] $FilePattern
    )

    if ($null -eq $FilePattern -or @($FilePattern).Count -eq 0) {
        return $true
    }

    $fileName = Split-Path -Path $FilePath -Leaf
    foreach ($pattern in @($FilePattern)) {
        if ($FilePath -like $pattern -or $fileName -like $pattern) {
            return $true
        }
    }

    return $false
}

function Split-BulkReplaceContentLine {
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory)]
        [string] $Content
    )

    if ([string]::IsNullOrEmpty($Content)) {
        return @('')
    }

    return [regex]::Split($Content, '\r\n|\n|\r')
}

function Get-BulkReplaceLineHit {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Content,

        [Parameter(Mandatory)]
        [pscustomobject] $Rule,

        [Parameter(Mandatory)]
        [string] $FilePath
    )

    $lines = @(Split-BulkReplaceContentLine -Content $Content)
    $hits = [List[object]]::new()

    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        $matched = if ($Rule.Regex) {
            $regexOptions = [RegexOptions]::None
            if ($Rule.IgnoreCase) {
                $regexOptions = $regexOptions -bor [RegexOptions]::IgnoreCase
            }

            [Regex]::IsMatch($line, $Rule.Pattern, $regexOptions)
        } else {
            if ($Rule.IgnoreCase) {
                $line.IndexOf($Rule.Pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
            } else {
                $line.Contains($Rule.Pattern)
            }
        }

        if ($matched) {
            $hits.Add([pscustomobject]@{
                    FilePath   = $FilePath
                    RuleName   = $Rule.Name
                    Pattern    = $Rule.Pattern
                    LineNumber = $index + 1
                    LineText   = $line
                })
        }
    }

    return $hits
}

function Get-BulkReplaceLineDiff {
    [CmdletBinding()]
    [OutputType([object[]])]
    param (
        [Parameter(Mandatory)]
        [string] $Before,

        [Parameter(Mandatory)]
        [string] $After,

        [Parameter(Mandatory)]
        [string] $RuleName,

        [Parameter(Mandatory)]
        [string] $FilePath
    )

    $beforeLines = @(Split-BulkReplaceContentLine -Content $Before)
    $afterLines = @(Split-BulkReplaceContentLine -Content $After)
    $lineCount = [Math]::Max($beforeLines.Count, $afterLines.Count)
    $changes = [List[object]]::new()

    for ($index = 0; $index -lt $lineCount; $index++) {
        $beforeLine = if ($index -lt $beforeLines.Count) { $beforeLines[$index] } else { $null }
        $afterLine = if ($index -lt $afterLines.Count) { $afterLines[$index] } else { $null }

        if ($beforeLine -ne $afterLine) {
            $changes.Add([pscustomobject]@{
                    FilePath        = $FilePath
                    RuleName        = $RuleName
                    LineNumber      = $index + 1
                    OriginalLine    = $beforeLine
                    ReplacementLine = $afterLine
                })
        }
    }

    return $changes
}

function Get-BulkReplaceTargetFile {
    [CmdletBinding()]
    [OutputType([object[]])]
    param (
        [Parameter(Mandatory)]
        [string[]] $Path,

        [string[]] $Include,

        [string[]] $Exclude,

        [switch] $Recurse
    )

    $resolvedFiles = [List[object]]::new()

    foreach ($targetPath in $Path) {
        $resolvedTargets = Resolve-Path -Path $targetPath -ErrorAction Stop
        foreach ($resolvedTarget in $resolvedTargets) {
            if (Test-Path -LiteralPath $resolvedTarget.Path -PathType Leaf) {
                $resolvedFiles.Add([pscustomobject]@{
                        FullName = $resolvedTarget.Path
                    })
                continue
            }

            $childParameters = @{
                LiteralPath = $resolvedTarget.Path
                File        = $true
            }

            if ($Recurse) {
                $childParameters.Recurse = $true
            }

            foreach ($childItem in Get-ChildItem @childParameters) {
                $fileName = $childItem.Name
                $includeMatch = $Include.Count -eq 0 -or ($Include | Where-Object { $fileName -like $_ }).Count -gt 0
                $excludeMatch = ($Exclude | Where-Object { $fileName -like $_ }).Count -gt 0

                if ($includeMatch -and -not $excludeMatch) {
                    $resolvedFiles.Add($childItem)
                }
            }
        }
    }

    $resolvedFiles | Sort-Object -Property FullName -Unique
}

function Invoke-BulkReplaceLiteral {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Content,

        [Parameter(Mandatory)]
        [string] $Pattern,

        [Parameter(Mandatory)]
        [string] $Replacement,

        [switch] $FirstOnly,

        [switch] $IgnoreCase
    )

    $comparison = if ($IgnoreCase) {
        [System.StringComparison]::OrdinalIgnoreCase
    } else {
        [System.StringComparison]::Ordinal
    }

    if ($FirstOnly) {
        $index = $Content.IndexOf($Pattern, $comparison)
        if ($index -lt 0) {
            return [pscustomobject]@{
                Content          = $Content
                ReplacementCount = 0
            }
        }

        $updatedContent = $Content.Remove($index, $Pattern.Length).Insert($index, $Replacement)
        return [pscustomobject]@{
            Content          = $updatedContent
            ReplacementCount = 1
        }
    }

    $replacementCount = 0
    $cursor = 0
    while ($true) {
        $index = $Content.IndexOf($Pattern, $cursor, $comparison)
        if ($index -lt 0) {
            break
        }

        $replacementCount++
        $cursor = $index + [Math]::Max(1, $Pattern.Length)
    }

    $updatedContent = if ($IgnoreCase) {
        $regex = [Regex]::new(
            [Regex]::Escape($Pattern),
            [RegexOptions]::IgnoreCase
        )
        $regex.Replace(
            $Content,
            [MatchEvaluator] { param($match) $Replacement }
        )
    } else {
        $Content.Replace($Pattern, $Replacement)
    }

    return [pscustomobject]@{
        Content          = $updatedContent
        ReplacementCount = $replacementCount
    }
}

function Invoke-BulkReplaceRegex {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Content,

        [Parameter(Mandatory)]
        [string] $Pattern,

        [Parameter(Mandatory)]
        [string] $Replacement,

        [switch] $FirstOnly,

        [switch] $IgnoreCase
    )

    $options = [RegexOptions]::Multiline
    if ($IgnoreCase) {
        $options = $options -bor [RegexOptions]::IgnoreCase
    }

    $regex = [Regex]::new($Pattern, $options)
    if ($FirstOnly) {
        $replacementCount = if ($regex.IsMatch($Content)) { 1 } else { 0 }
        $updatedContent = $regex.Replace($Content, $Replacement, 1)
    } else {
        $replacementCount = $regex.Matches($Content).Count
        $updatedContent = $regex.Replace($Content, $Replacement)
    }

    return [pscustomobject]@{
        Content          = $updatedContent
        ReplacementCount = $replacementCount
    }
}

$rawRules = @(
    Resolve-BulkReplaceRuleInput `
        -Rule $Rule `
        -RulePath $RulePath `
        -Find $Find `
        -Replace $Replace `
        -UseRegex:$UseRegex `
        -FirstOnly:$FirstOnly `
        -IgnoreCase:$IgnoreCase `
        -FilePattern $FilePattern `
        -SearchOnly:$SearchOnly
)

$normalizedRules = for ($index = 0; $index -lt $rawRules.Count; $index++) {
    ConvertTo-BulkReplaceRule `
        -InputRule $rawRules[$index] `
        -Index ($index + 1) `
        -SearchOnly:$SearchOnly
}

if ($normalizedRules.Count -eq 0) {
    throw 'No valid replacement rules were supplied.'
}

$targetFiles = @(
    Get-BulkReplaceTargetFile -Path $Path -Include $Include -Exclude $Exclude -Recurse:$Recurse
)

if ($targetFiles.Count -eq 0) {
    throw 'No files matched the supplied path and file pattern filters.'
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$reports = [List[object]]::new()
$searchHits = [List[object]]::new()
$totalReplacementCount = 0
$changedFileCount = 0
$previewFileCount = 0

foreach ($file in $targetFiles) {
    $currentContent = [System.IO.File]::ReadAllText($file.FullName)
    $workingContent = $currentContent
    $fileReplacementCount = 0
    $appliedRules = [List[string]]::new()
    $fileChanges = [List[object]]::new()

    if ($SearchOnly) {
        foreach ($ruleItem in $normalizedRules) {
            if (-not (Test-BulkReplaceFilePattern -FilePath $file.FullName -FilePattern $ruleItem.FilePattern)) {
                continue
            }

            foreach ($hit in @(Get-BulkReplaceLineHit -Content $currentContent -Rule $ruleItem -FilePath $file.FullName)) {
                $searchHits.Add($hit)
            }
        }

        continue
    }

    foreach ($ruleItem in $normalizedRules) {
        if (-not (Test-BulkReplaceFilePattern -FilePath $file.FullName -FilePattern $ruleItem.FilePattern)) {
            continue
        }

        $appliedRules.Add($ruleItem.Name)

        $ReplaceParams = @{
            Content     = $workingContent
            Pattern     = $ruleItem.Pattern
            Replacement = $ruleItem.Replacement
            FirstOnly   = $ruleItem.FirstOnly
            IgnoreCase  = $ruleItem.IgnoreCase
        }

        $result = if ($ruleItem.Regex) {
            Invoke-BulkReplaceRegex @ReplaceParams
        } else {
            Invoke-BulkReplaceLiteral @ReplaceParams
        }

        if ($result.Content -ne $workingContent) {
            $Changes = Get-BulkReplaceLineDiff `
                -Before $workingContent `
                -After $result.Content `
                -RuleName $ruleItem.Name `
                -FilePath $file.FullName

            foreach ($change in $Changes) {
                $fileChanges.Add($change)
            }
        }

        $workingContent = $result.Content
        $fileReplacementCount += $result.ReplacementCount
    }

    if ($appliedRules.Count -eq 0) {
        continue
    }

    $wouldChange = $workingContent -ne $currentContent
    $changed = $false

    if ($wouldChange -and $PSCmdlet.ShouldProcess($file.FullName, "Apply $fileReplacementCount replacement(s)")) {
        [System.IO.File]::WriteAllText($file.FullName, $workingContent, $utf8NoBom)
        $changed = $true
    }

    if ($wouldChange) {
        $previewFileCount++
    }

    if ($changed) {
        $changedFileCount++
        $totalReplacementCount += $fileReplacementCount
    }

    $lineNumbers = @()
    foreach ($change in $fileChanges) {
        $lineNumbers += $change.LineNumber
    }

    $changeReports = @()
    foreach ($change in $fileChanges) {
        $changeReports += $change
    }

    $reports.Add([pscustomobject]@{
            Path             = $file.FullName
            Changed          = $changed
            WouldChange      = $wouldChange
            ReplacementCount = $fileReplacementCount
            AppliedRules     = @($appliedRules)
            LineNumbers      = $lineNumbers
            Changes          = $changeReports
        })
}

if ($SearchOnly) {
    if ($searchHits.Count -eq 0) {
        Write-Host 'No matching lines found.'
    } else {
        Write-Host ("Found {0} matching line(s)." -f $searchHits.Count)
    }
} elseif ($previewFileCount -eq 0) {
    Write-Host 'No files required changes.'
} elseif ($changedFileCount -gt 0) {
    Write-Host ("Updated {0} file(s) with {1} replacement(s)." -f $changedFileCount, $totalReplacementCount)
} else {
    Write-Host ("Previewed {0} file(s); {1} replacement(s) would be applied." -f $previewFileCount, ($reports | Measure-Object -Property ReplacementCount -Sum).Sum)
}

if ($PassThru) {
    if ($SearchOnly) {
        if ($PassThruFormat -eq 'Detailed') {
            Write-Output ($searchHits.ToArray()) -NoEnumerate
            return
        }

        $summarySearchHits = @(
            $searchHits |
                Group-Object -Property FilePath, RuleName |
                ForEach-Object {
                    $first = $_.Group | Select-Object -First 1
                    [pscustomobject]@{
                        FilePath    = $first.FilePath
                        RuleName    = $first.RuleName
                        MatchCount  = $_.Count
                        LineNumbers = @($_.Group | ForEach-Object { $_.LineNumber })
                    }
                }
        )

        Write-Output $summarySearchHits -NoEnumerate
        return
    }

    if ($PassThruFormat -eq 'Detailed') {
        Write-Output ($reports.ToArray()) -NoEnumerate
        return
    }

    $summaryReports = @(
        $reports | ForEach-Object {
            [pscustomobject]@{
                Path             = $_.Path
                Changed          = $_.Changed
                WouldChange      = $_.WouldChange
                ReplacementCount = $_.ReplacementCount
                AppliedRuleCount = @($_.AppliedRules).Count
            }
        }
    )

    Write-Output $summaryReports -NoEnumerate
    return
}
