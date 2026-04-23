$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path

$script:LastDialogResult = $false

# Create module var to map names to controls
if (-not $Script:WPFControlTable) {
    $Script:WPFControlTable = @{}
}

if (-not $Script:WPFThemeTable) {
    $Script:WPFThemeTable = @{}
}

if (-not $Script:WPFStyleTable) {
    $Script:WPFStyleTable = @{}
}

if (-not $Script:WPFImplicitStyleTable) {
    $Script:WPFImplicitStyleTable = @{}
}

if (-not $Script:WPFThemeState) {
    $Script:WPFThemeState = [ordered]@{
        ActiveTheme = $null
    }
}

# Load FileInfo objects
if (-not $Script:WPFFileInfo) {
    $Script:WPFFileInfo = Import-PowerShellDataFile -Path "$ModuleRoot/Private/Data/FileInfo.psd1"
}

$Paths = @(
    'Private'
    'Public'
)

foreach ($Path in $Paths) {
    Get-ChildItem "$ModuleRoot/$Path" -Recurse -Filter '*.ps1' |
        ForEach-Object {
            . $_.FullName
        }
}
