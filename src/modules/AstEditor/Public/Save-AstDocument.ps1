using namespace System.IO

<#
.SYNOPSIS
    Commits validated document output using a staged, atomic file replacement.

.DESCRIPTION
    Preserves source encoding, BOM, and existing newline characters. The source
    fingerprint is checked after confirmation and immediately before committing.
    No destructive overwrite fallback is used if atomic replacement is unavailable.
    Returns an AstEditor.WriteResult with WasWritten, WriteStatus, ParseErrors,
    and ErrorRecord. Expected validation and I/O failures are reported in that
    result; callers must check WasWritten before reporting an applied edit.

    In-memory documents require OutPath and default to UTF-8 without a BOM.

.EXAMPLE
    $Result = Save-AstDocument -Document $Document -WhatIf
    $Result.WriteStatus
#>
function Save-AstDocument {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('AstEditor.WriteResult')]
    param (
        [Parameter(Mandatory)]
        [AstDocument] $Document,

        [string] $OutPath
    )

    $Result = [pscustomobject]@{
        PSTypeName = 'AstEditor.WriteResult'
        Path = $null
        OriginalFingerprint = $Document.OriginalFingerprint
        WasWritten = $false
        WriteStatus = 'NotAttempted'
        ParseErrors = @()
        ErrorRecord = $null
        CleanupErrorRecord = $null
    }
    $TemporaryPath = $null
    $OwnsTemporaryFile = $false
    try {
        if (-not $OutPath -and -not $Document.IsFileBacked) {
            $Result.WriteStatus = 'InvalidTarget'
            throw [ArgumentException]::new('An in-memory document requires OutPath to save.')
        }
        $TargetPath = if ($OutPath) {
            $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutPath)
        } else {
            $Document.Path
        }
        $Result.Path = $TargetPath
        $Validation = Resolve-AstDocument -Document $Document -PassThruText
        $Result.ParseErrors = @($Validation.ParseErrors)
        if ($Validation.ParseErrorCount -gt 0) {
            $Result.WriteStatus = 'FailedValidation'
            throw [ArgumentException]::new(
                "Cannot save rendered output. Parse errors detected: $($Validation.ParseErrorCount)."
            )
        }

        $TargetExists = [File]::Exists($TargetPath)
        $TargetFingerprint = if ($TargetExists) {
            Get-AstSourceFingerprint -Bytes ([File]::ReadAllBytes($TargetPath))
        }
        if (-not $PSCmdlet.ShouldProcess($TargetPath, 'Write rendered AST overlay output')) {
            $Result.WriteStatus = if ($WhatIfPreference) { 'WhatIf' } else { 'Declined' }
            return $Result
        }

        $Preamble = $Document.SourceEncoding.GetPreamble()
        $Content = $Document.SourceEncoding.GetBytes($Validation.RenderedText)
        $TemporaryPath = Join-Path ([Path]::GetDirectoryName($TargetPath)) (
            '.{0}.{1}.tmp' -f [Path]::GetFileName($TargetPath), [Guid]::NewGuid().ToString('N')
        )
        $Stream = [FileStream]::new(
            $TemporaryPath, [FileMode]::CreateNew, [FileAccess]::Write, [FileShare]::None
        )
        $OwnsTemporaryFile = $true
        try {
            $Stream.Write($Preamble, 0, $Preamble.Length)
            $Stream.Write($Content, 0, $Content.Length)
            $Stream.Flush($true)
        } finally {
            $Stream.Dispose()
        }

        if ($Document.IsFileBacked -and
            (-not [File]::Exists($Document.Path) -or
                (Get-AstSourceFingerprint -Bytes ([File]::ReadAllBytes($Document.Path))) -cne
                    $Document.OriginalFingerprint)
        ) {
            $Result.WriteStatus = 'StaleSource'
            throw [IOException]::new('The source file changed after the document snapshot was created.')
        }
        if ([File]::Exists($TargetPath) -ne $TargetExists -or
            ($TargetExists -and
                (Get-AstSourceFingerprint -Bytes ([File]::ReadAllBytes($TargetPath))) -cne
                    $TargetFingerprint)
        ) {
            $Result.WriteStatus = 'StaleTarget'
            throw [IOException]::new('The destination file changed before the transaction could commit.')
        }

        Invoke-AstFileReplacement `
            -TemporaryPath $TemporaryPath `
            -TargetPath $TargetPath `
            -TargetExists:$TargetExists
        $Result.WasWritten = $true
        $Result.WriteStatus = 'Written'
    } catch [IOException], [UnauthorizedAccessException], [ArgumentException], [NotSupportedException] {
        if ($Result.WriteStatus -eq 'NotAttempted') {
            $Result.WriteStatus = 'FailedWrite'
        }
        $Result.ErrorRecord = $_
    } finally {
        if ($OwnsTemporaryFile -and [File]::Exists($TemporaryPath)) {
            try {
                [File]::Delete($TemporaryPath)
            } catch [IOException], [UnauthorizedAccessException] {
                $Result.CleanupErrorRecord = $_
                if (-not $Result.ErrorRecord) {
                    $Result.ErrorRecord = $_
                    $Result.WriteStatus = 'FailedWrite'
                }
            }
        }
    }

    return $Result
}
