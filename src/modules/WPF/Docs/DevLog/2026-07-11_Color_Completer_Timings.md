Watched Ben Reader's [talk on argument completers](https://www.youtube.com/watch?v=hYWCus5qPLc). Learned that ArgumentCompleter classes were a thing. `[ColorCompleter()]` is a bit nicer than `[ArgumentCompleter({ Complete-WPFColor @args })]`. After the conversion, I spoke with Gemini to see if there was any room for optimization and came out with a few variations on the original. Timing results seem to fluctuate *wildly* but on average `ColorCompleter3` seems to outperform the rest by avoiding idiomatic Powershell.

Arguably, piping everything is more memory efficient but that doesn't seem necessary here.

Unfortunately, this method suffers from the same issue that plagues all Powershell class usage (ie. the need to use `using module`) to load the class definitions. At least the optimizations can be moved into `Complete-WPFColor` and friends.

**Timing Results**
```
Word Completion Results:
Complete-WPFColor: 4.8174
ColorCompleter: 1.2739
ColorCompleter2: 0.7927
ColorCompleter3: 0.6364
ColorCompleter4: 1.2162
 
Blank Completion Results:
Complete-WPFColor: 3.6649
ColorCompleter: 8.3014
ColorCompleter2: 0.5778
ColorCompleter3: 0.3976
ColorCompleter4: 9.6722
```

**Implementations**
```powershell
using namespace System
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language


function Complete-WPFColor {
    [CmdletBinding()]
    [OutputType([CompletionResult], [CompletionResult[]])]
    param(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [CommandAst] $CommandAst,
        [IDictionary] $FakeBoundParameters
    )

    $Completions = @(
        [System.Windows.Media.Colors].GetProperties().Name
    )

    # The results are already alphabetical so no need to sort these.
    $Completions = $Completions |
        Where-Object { $_ -ilike "*$WordToComplete*" } |
        Sort-Object -Property @(
            {
                # Tie results when no search term is provided to maintain alphabetical order.
                if ([string]::IsNullOrWhiteSpace($WordToComplete)) { 0 }
                # Otherwise, prioritize results that start with the search term.
                else { [int]($_ -inotlike "$WordToComplete*") }
            },
            { $_  <# Always keep deterministic alphabetical ordering. #> }
        ) |
        ForEach-Object {
            $CompletionText = if ($Quote) { $Quote + $_ + $Quote  } else { $_ }
            [CompletionResult]::new(
                <# Text to insert #> $CompletionText,
                <# Text displayed in the list #> $_,
                <# Result type #> [CompletionResultType]::ParameterValue,
                <# Tooltip #> "Color"
            )
        }

    if ($Completions.Count -gt 0) { return $Completions }
    return $null  # Prevent fallback autocomplete
}


class ColorCompleter : System.Management.Automation.IArgumentCompleter {

    static [string[]] $Colors = [System.Windows.Media.Colors].GetProperties().Name

    ColorCompleter() {}

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [CommandAst] $CommandAst,
        [IDictionary] $FakeBoundParameters
    ) {
        [List[CompletionResult]] $Completions = [List[CompletionResult]]::new()

        # The results are already alphabetical so no need to sort these.
        $Completions = [ColorCompleter]::Colors |
            Where-Object { $_ -ilike "*$WordToComplete*" } |
            Sort-Object -Property @(
                {
                    # Tie results when no search term is provided to maintain alphabetical order.
                    if ([string]::IsNullOrWhiteSpace($WordToComplete)) { 0 }
                    # Otherwise, prioritize results that start with the search term.
                    else { [int]($_ -inotlike "$WordToComplete*") }
                },
                { $_  <# Always keep deterministic alphabetical ordering. #> }
            ) |
            ForEach-Object {
                $Completions.Add(
                    [CompletionResult]::new(
                        <# Text to insert #> $_,
                        <# Text displayed in the list #> $_,
                        <# Result type #> [CompletionResultType]::ParameterValue,
                        <# Tooltip #> "Color"
                    )
                )
            }

        if ($Completions.Count -gt 0) { return $Completions }
        return $null  # Prevent fallback autocomplete
    }
}


class ColorCompleter2 : System.Management.Automation.IArgumentCompleter {

    static [string[]] $Colors = [System.Windows.Media.Colors].GetProperties().Name

    ColorCompleter2() {}

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [CommandAst] $CommandAst,
        [IDictionary] $FakeBoundParameters
    ) {
        [List[CompletionResult]] $Completions = [List[CompletionResult]]::new()

        $IsBlank = [string]::IsNullOrWhiteSpace($WordToComplete)
        if ($IsBlank) {
            [ColorCompleter2]::Colors.Foreach({
                $Completions.Add(
                    [CompletionResult]::new(
                        <# Text to insert #> $_,
                        <# Text displayed in the list #> $_,
                        <# Result type #> [CompletionResultType]::ParameterValue,
                        <# Tooltip #> "Color"
                    )
                )
            })
            return $Completions
        }

        # The results are already alphabetical so no need to sort these.
        $Completions = [ColorCompleter]::Colors.
            Where({ $_ -ilike "*$WordToComplete*" }) |
            Sort-Object -Property @(
                {
                    # Tie results when no search term is provided to maintain alphabetical order.
                    if ($IsBlank) { 0 }
                    # Otherwise, prioritize results that start with the search term.
                    else { [int]($_ -inotlike "$WordToComplete*") }
                },
                { $_  <# Always keep deterministic alphabetical ordering. #> }
            ) |
            ForEach-Object {
                $Completions.Add(
                    [CompletionResult]::new(
                        <# Text to insert #> $_,
                        <# Text displayed in the list #> $_,
                        <# Result type #> [CompletionResultType]::ParameterValue,
                        <# Tooltip #> "Color"
                    )
                )
            }

        if ($Completions.Count -gt 0) { return $Completions }
        return $null  # Prevent fallback autocomplete
    }
}

class ColorCompleter3 : System.Management.Automation.IArgumentCompleter {

    static [string[]] $Colors = [System.Windows.Media.Colors].GetProperties().Name
    static [List[CompletionResult]] $PreComputedResults = @(
        foreach($Color in [System.Windows.Media.Colors].GetProperties().Name) {
            [CompletionResult]::new(
                <# Text to insert #> $Color,
                <# Text displayed in the list #> $Color,
                <# Result type #> [CompletionResultType]::ParameterValue,
                <# Tooltip #> "Color"
            )
        }
    )

    ColorCompleter3() {}

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [CommandAst] $CommandAst,
        [IDictionary] $FakeBoundParameters
    ) {
        [List[CompletionResult]] $Completions = [List[CompletionResult]]::new()

        # Use native .Where() for initial filtering to bypass pipeline overhead.
        # If input is blank/null, return all colors; otherwise, filter out non-matching colors
        $IsBlank = [string]::IsNullOrWhiteSpace($WordToComplete)
        $FilteredColors =
            if ($IsBlank) { [ColorCompleter3]::PreComputedResults }
            else { [ColorCompleter3]::Colors.Where({ $_ -ilike "*$WordToComplete*" }) }


        # Handle sorting logic using native arrays instead of Sort-Object to avoid
        # scriptblock overhead.
        if (-not $IsBlank) {
            [List[String]] $StartsWith = [List[String]]::new()
            [List[String]] $ContainsOnly = [List[String]]::new()

            foreach ($color in $FilteredColors) {
                if ($color -ilike "$WordToComplete*") {
                    $StartsWith.Add($color)
                } else {
                    $ContainsOnly.Add($color)
                }
            }

            # Recombine into a single list with prioritized ordering.
            $FilteredColors = $StartsWith + $ContainsOnly
        }

        # The results are already alphabetical so no need to sort these.
        foreach ($Color in $FilteredColors) {
            $Completions.Add(
                [CompletionResult]::new(
                    <# Text to insert #> $Color,
                    <# Text displayed in the list #> $Color,
                    <# Result type #> [CompletionResultType]::ParameterValue,
                    <# Tooltip #> "Color"
                )
            )
        }

        if ($Completions.Count -gt 0) { return $Completions }
        return $null  # Prevent fallback autocomplete
    }
}

class ColorCompleter4 : System.Management.Automation.IArgumentCompleter {

    static [string[]] $Colors = [System.Windows.Media.Colors].GetProperties().Name
    static [List[CompletionResult]] $PreComputedResults = @(
        foreach($Color in [System.Windows.Media.Colors].GetProperties().Name) {
            [CompletionResult]::new(
                <# Text to insert #> $Color,
                <# Text displayed in the list #> $Color,
                <# Result type #> [CompletionResultType]::ParameterValue,
                <# Tooltip #> "Color"
            )
        }
    )

    ColorCompleter4() {}

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [CommandAst] $CommandAst,
        [IDictionary] $FakeBoundParameters
    ) {
        # Native filtering using precomputed results.
        $Matches = [ColorCompleter4]::PreComputedResults.Where({ $_.CompletionText -ilike "*$WordToComplete*" })
        if ($Matches.Count -eq 0) { return $null }

        # Convert matches to a flat array so we can use [System.Array]::Sort
        [CompletionResult[]] $SortedArray = $Matches

        [System.Array]::Sort($SortedArray, [System.Comparison[CompletionResult]]{
            param($a, $b)

            $xStartsWith = $a.CompletionText.StartsWith($WordToComplete, [System.StringComparison]::OrdinalIgnoreCase)
            $yStartsWith = $b.CompletionText.StartsWith($WordToComplete, [System.StringComparison]::OrdinalIgnoreCase)

            if ($xStartsWith -and -not $yStartsWith) { return -1 }  # X comes first
            if (-not $xStartsWith -and $yStartsWith) { return 1 }  # Y comes first

            # Fall back to alphabetical comparison if they fall in the same priority bucket.
            return [string]::Compare($a.CompletionText, $b.CompletionText, $true)
        })

        return $SortedArray -as [List[CompletionResult]]
    }
}


$Time1 = Measure-Command { Complete-WPFColor -WordToComplete 'Whi' }
$Time2 = Measure-Command { [colorcompleter]::new().CompleteArgument($null, $null, 'Whi', $null, $null) }
$Time3 = Measure-Command { [colorcompleter2]::new().CompleteArgument($null, $null, 'Whi', $null, $null) }
$Time4 = Measure-Command { [colorcompleter3]::new().CompleteArgument($null, $null, 'Whi', $null, $null) }
$Time5 = Measure-Command { [colorcompleter4]::new().CompleteArgument($null, $null, 'Whi', $null, $null) }


Write-Output "Word Completion Results:"
Write-Output "Complete-WPFColor: $($Time1.TotalMilliseconds)"
Write-Output "ColorCompleter: $($Time2.TotalMilliseconds)"
Write-Output "ColorCompleter2: $($Time3.TotalMilliseconds)"
Write-Output "ColorCompleter3: $($Time4.TotalMilliseconds)"
Write-Output "ColorCompleter4: $($Time5.TotalMilliseconds)"

$Time1 = Measure-Command { Complete-WPFColor -WordToComplete '' }
$Time2 = Measure-Command { [colorcompleter]::new().CompleteArgument($null, $null, '', $null, $null) }
$Time3 = Measure-Command { [colorcompleter2]::new().CompleteArgument($null, $null, '', $null, $null) }
$Time4 = Measure-Command { [colorcompleter3]::new().CompleteArgument($null, $null, '', $null, $null) }
$Time5 = Measure-Command { [colorcompleter4]::new().CompleteArgument($null, $null, '', $null, $null) }

Write-Output " "
Write-Output "Blank Completion Results:"
Write-Output "Complete-WPFColor: $($Time1.TotalMilliseconds)"
Write-Output "ColorCompleter: $($Time2.TotalMilliseconds)"
Write-Output "ColorCompleter2: $($Time3.TotalMilliseconds)"
Write-Output "ColorCompleter3: $($Time4.TotalMilliseconds)"
Write-Output "ColorCompleter4: $($Time5.TotalMilliseconds)"
```
