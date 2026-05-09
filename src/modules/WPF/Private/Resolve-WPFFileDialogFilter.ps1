function Resolve-WPFFileDialogFilter {
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [string[]] $Type,
        [string[]] $Category,
        [string[]] $Filter
    )

    $AllFilesFilter = 'All Files (*.*)|*.*'
    $CandidateFilters = @()

    if ($Filter) {
        $CandidateFilters += $Filter
    }

    # Add aggregate category filters first so they become the default selection.
    foreach ($Entry in $Category) {
        $Extensions = Get-WPFFileInfo -Category $Entry |
            ForEach-Object {
                if ($_ -isnot [hashtable] -or -not $_.ContainsKey('Extensions')) {
                    return
                }

                $Value = $_['Extensions']
                if ($Value -is [System.Array]) {
                    foreach ($Extension in $Value) {
                        if ($Extension) {
                            "*.$Extension"
                        }
                    }
                } elseif ($Value) {
                    "*.$Value"
                }
            } |
            Sort-Object -Unique

        if ($Extensions) {
            $Display = if ($Entry.EndsWith('s')) {
                "All $Entry"
            } else {
                "All $($Entry)s"
            }
            $JoinedExtensions = $Extensions -join ';'
            $CandidateFilters += "$Display ($JoinedExtensions)|$JoinedExtensions"
        }
    }

    $GetFileInfoParams = @{}
    if ($Type) {
        $GetFileInfoParams.Type = $Type
    }
    if ($Category) {
        $GetFileInfoParams.Category = $Category
    }

    # Get-WPFFileInfo returns hashtables; use key lookup for PS5 compatibility.
    $ResolvedFilters = Get-WPFFileInfo @GetFileInfoParams |
        ForEach-Object {
            if ($_ -is [hashtable] -and $_.ContainsKey('Filter')) {
                $_['Filter']
            }
        }

    if ($ResolvedFilters) {
        $CandidateFilters += $ResolvedFilters
    }

    if (-not $CandidateFilters) {
        return @()
    }

    # Remove duplicates while preserving first-seen order.
    $Seen = @{}
    $UniqueFilters = @()
    foreach ($Entry in $CandidateFilters) {
        if (-not $Seen.ContainsKey($Entry)) {
            $Seen[$Entry] = $true
            $UniqueFilters += $Entry
        }
    }

    # Keep the broad fallback available, but always place it last.
    $UniqueFilters = $UniqueFilters | Where-Object { $_ -ne $AllFilesFilter }
    return @($UniqueFilters + $AllFilesFilter)
}
