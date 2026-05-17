$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path

$script:LastDialogResult = $false
$script:LastDialogCloseReason = 'Unknown'

# Create module var to map context ids to control tables
if (-not $Script:WPFControlRegistry) {
    $Script:WPFControlRegistry = [ordered] @{
        ActiveContextId = $null
        Contexts        = @{}
    }
}

if (-not $Script:WPFDialogCloseReasonByContextId) {
    $Script:WPFDialogCloseReasonByContextId = @{}
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
    'TypeConverters'
)

foreach ($Path in $Paths) {
    Get-ChildItem "$ModuleRoot/$Path" -Recurse -Filter '*.ps1' |
        ForEach-Object {
            . $_.FullName
        }
}
