$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/AstOverlay.ps1"

# --- Source: any well-formed script text ---

$Source = @'
function Greet {
    param([string] $Name)
    Write-Host "Hello, $Name!"
}
'@

# --- 1. Parse into an overlay document ---

$Overlay = New-AstDocument -InputObject $Source

# --- 2. Find the node we want to change ---
#    Replace the Write-Host call with one that uses Write-Output instead.

$WriteHostCall = $Overlay.Ast.Find({
        param($Node)
        $Node -is [System.Management.Automation.Language.CommandAst] -and
        $Node.GetCommandName() -eq 'Write-Host'
    }, $true)

if (-not $WriteHostCall) {
    throw 'Write-Host call not found in source.'
}

# --- 3. Queue the edit ---

$Overlay.PrependLine($WriteHostCall, 'Write-Output "....testing, mic check..."', 'Insert greeting before Write-Host')
$Overlay.Replace($WriteHostCall, 'Write-Output "Hello, $Name!"', 'Replace Write-Host with Write-Output')
$Overlay.AppendLine($WriteHostCall, 'Write-Output "Welcome to the AstOverlayLab!"', 'Insert additional greeting after Write-Host')

# --- 4. Render and validate ---

$Result = Resolve-AstDocument -Document $Overlay -PassThruText

if ($Result.ParseErrorCount -gt 0) {
    Write-Host "Parse errors after mutation:"
    $Result.ParseErrors | ForEach-Object { Write-Host "  $_" }
    exit 1
}

Write-Host "=== Original ==="
Write-Host $Source
Write-Host "=== Mutated ==="
Write-Host $Result.RenderedText
Write-Host "Edits applied: $($Result.EditCount)"
