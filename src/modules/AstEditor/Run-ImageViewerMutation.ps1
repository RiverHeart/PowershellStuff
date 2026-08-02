$ErrorActionPreference = 'Stop'

$ModulesRoot = Split-Path -Parent $PSScriptRoot
$SourceRoot = Split-Path -Parent $ModulesRoot

Import-Module "$PSScriptRoot/AstEditor.psd1" -Force

$SourcePath = Join-Path $SourceRoot 'modules/WPF/Examples/ImageViewer/ImageViewer.DSL.ps1'
$OutputPath = Join-Path $PSScriptRoot 'ImageViewer.DSL.mutated.ps1'

$Document = New-AstDocument -Path $SourcePath

$Inserted = Add-WpfDslLoadedHandler -Document $Document -OnExistingHandler InsertAfterExisting -HandlerBody "Write-Verbose 'Loaded handler from AstEditor.'"
if (-not $Inserted) {
    Write-Host 'Loaded handler already exists in source. Use -Force in Add-WpfDslLoadedHandler to reinsert.'
}

$Validation = Resolve-AstDocument -Document $Document -PassThruText
if ($Validation.ParseErrorCount -gt 0) {
    Write-Host "Validation failed with $($Validation.ParseErrorCount) parse errors."
    $Validation.ParseErrors | ForEach-Object {
        Write-Host "  $($_.Message) at $($_.Extent.StartLineNumber):$($_.Extent.StartColumnNumber)"
    }
    exit 1
}

[System.IO.File]::WriteAllText($OutputPath, $Validation.RenderedText)
Write-Host "Mutated script written to: $OutputPath"
Write-Host "Edits applied: $($Validation.EditCount)"
