function Get-WPFFileInfo {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [ArgumentCompleter({ Complete-WPFFileInfo @args -Type })]
        [string[]] $Type,

        [ArgumentCompleter({ Complete-WPFFileInfo @args -Category })]
        [string[]] $Category
    )

    process {
        $FoundItems = @()

        # Load FileInfo objects
        # Useful when testing outside of module
        if (-not $Script:WPFFileInfo) {
            $Script:WPFFileInfo = Import-PowerShellDataFile -Path "$PSScriptRoot/../../Private/Data/FileInfo.psd1"
        }

        # Search for FileInfo by type
        foreach ($Entry in $Type) {
            if ($Script:WPFFileInfo.FileInfo.ContainsKey($Entry)) {
                Write-Output $Script:WPFFileInfo.FileInfo[$Entry]
                $FoundItems += $Entry
            }
        }

        # If no category, stop here
        if (-not $Category) {
            return
        }

        # Find FileInfos in the given category
        foreach($KVP in $Script:WPFFileInfo.FileInfo.GetEnumerator()) {
            $Key, $FileInfo = $KVP.Key, $KVP.Value

            # Ignore items already found, either by name or category
            if ($Key -in $FoundItems) {
                continue
            }

            # Check if the FileInfo has one of the categories
            foreach($Entry in $Category) {
                if ($Entry -in $FileInfo.Categories) {
                    Write-Output $FileInfo
                    $FoundItems += $Key
                    break
                }
            }
        }
    }
}
