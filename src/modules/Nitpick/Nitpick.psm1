using namespace System
using namespace System.Management.Automation.Language

$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path

# MARK: NP_CORRECTION
#------------------

class NitpickCorrection {
    [int] $StartLineNumber
    [int] $EndLineNumber
    [int] $StartColumnNumber
    [int] $EndColumnNumber
    [string] $ReplacementText
    [string[]] $Lines  # No idea WTH this is for, maybe replacements that span multiple lines?
    [string] $FilePathOrContext
    [string] $Description

    NitpickCorrection(
        [IScriptExtent] $ViolationExtent,
        [string] $replacementText,
        [string] $filePathOrContext,
        [string] $description
    ) {
        $this.StartLineNumber = $ViolationExtent.StartLineNumber
        $this.EndLineNumber = $ViolationExtent.EndLineNumber
        $this.StartColumnNumber = $ViolationExtent.StartColumnNumber
        $this.EndColumnNumber = $ViolationExtent.EndColumnNumber
        $this.ReplacementText = $replacementText
        $this.FilePathOrContext = $filePathOrContext
        $this.Description = $description
    }

    NitpickCorrection(
        [int] $startLineNumber,
        [int] $endLineNumber,
        [int] $startColumnNumber,
        [int] $endColumnNumber,
        [string] $replacementText,
        [string] $filePathOrContext,
        [string] $description
    ) {
        $this.StartLineNumber = $startLineNumber
        $this.EndLineNumber = $endLineNumber
        $this.StartColumnNumber = $startColumnNumber
        $this.EndColumnNumber = $endColumnNumber
        $this.ReplacementText = $replacementText
        $this.FilePathOrContext = $filePathOrContext
        $this.Description = $description
    }

    NitpickCorrection([hashtable] $properties) {
        $this.StartLineNumber = $properties.StartLineNumber
        $this.EndLineNumber = $properties.EndLineNumber
        $this.StartColumnNumber = $properties.StartColumnNumber
        $this.EndColumnNumber = $properties.EndColumnNumber
        $this.ReplacementText = $properties.ReplacementText
        $this.FilePathOrContext = $properties.FilePathOrContext
        $this.Description = $properties.Description
    }

    [object] ToCorrectionExtent() {
        # Using `New-Object` to avoid type resolution issues at parse time
        $Result = New-Object 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent' -ArgumentList (
            $this.StartLineNumber,
            $this.EndLineNumber,
            $this.StartColumnNumber,
            $this.EndColumnNumber,
            $this.ReplacementText,
            $this.FilePathOrContext,
            $this.Description
        )
        return $Result
    }

}

# MARK: NP_FINDING
#------------------

class NitpickFinding {
    [IScriptExtent] $ViolationExtent
    [string] $Message
    [string] $RuleName
    [string] $RuleSuppressionID
    [string] $Severity
    [NitpickCorrection[]] $Corrections

    NitpickFinding(
        [IScriptExtent] $ViolationExtent,
        [string] $replacementText,
        [string] $filePathOrContext,
        [string] $description
    ) {
        $this.ViolationExtent = $ViolationExtent
        $this.Message = $replacementText
        $this.RuleName = $filePathOrContext
        $this.RuleSuppressionID = $description
        $this.Severity = $description
        $this.Corrections = @()
    }

    NitpickFinding([hashtable] $properties) {
        $this.ViolationExtent = $properties.ViolationExtent
        $this.Message = $properties.Message
        $this.RuleName = $properties.RuleName
        $this.RuleSuppressionID = $properties.RuleSuppressionID
        $this.Severity = $properties.Severity
        $this.Corrections = $properties.Corrections
    }

    [object] ToDiagnosticRecord() {
        # Using `New-Object` to avoid type resolution issues at parse time
        $CorrectionExtents = New-Object 'System.Collections.ObjectModel.Collection[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]'
        foreach ($Correction in $this.Corrections) {
            $CorrectionExtents.Add($Correction.ToCorrectionExtent())
        }

        $SeverityType = [AppDomain]::CurrentDomain.GetAssemblies() |
            ForEach-Object {
                $_.GetType(
                    'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticSeverity',
                    $false
                )
            } |
            Where-Object { $null -ne $_ } |
            Select-Object -First 1
        $DiagnosticSeverity = [Enum]::Parse($SeverityType, $this.Severity, $true)
        $DiagnosticRecordType = $SeverityType.Assembly.GetType(
            'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord',
            $true
        )
        $Constructor = $DiagnosticRecordType.GetConstructors() |
            Where-Object { $_.GetParameters().Count -eq 7 } |
            Select-Object -First 1
        $Arguments = [object[]]::new(7)
        $Arguments[0] = $this.Message
        $Arguments[1] = $this.ViolationExtent
        $Arguments[2] = $this.RuleName
        $Arguments[3] = $DiagnosticSeverity
        $Arguments[4] = $this.ViolationExtent.File
        $Arguments[5] = $this.RuleSuppressionID
        $Arguments[6] = $CorrectionExtents.PSObject.BaseObject
        $Result = $Constructor.Invoke($Arguments)
        return $Result
    }

}

$Paths = @(
    'Private'
    'Public'
)

foreach ($Path in $Paths) {
    Get-ChildItem -Path "$ModuleRoot/$Path" -Recurse -Filter '*.ps1' |
        ForEach-Object {
            . $_.FullName
        }
}
