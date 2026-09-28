using namespace System
using namespace System.Collections.ObjectModel
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path

# MARK: NP_CORRECTION
#----------------------

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

        $Result = New-Object 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord' -ArgumentList (
            $this.Message,
            $this.ViolationExtent,
            $this.RuleName,
            $this.Severity,
            $this.ViolationExtent.File,
            $this.RuleSuppressionID,
            $CorrectionExtents.PSObject.BaseObject
        )
        return $Result
    }
}

Update-TypeData `
    -TypeName 'NitpickFinding' `
    -DefaultDisplayPropertySet 'RuleName', 'Severity', 'Message' `
    -Force


# MARK: NP_RULE
#------------------

class NitpickRule {
    [string] $Name
    [string] $Category
    [string] $CallableType
    [object] $Callable
    [string] $Source
    [string] $Description
    [string] $Severity
    [string] $Explanation

    NitpickRule([object] $TargetCallable, [hashtable] $Overrides) {
        if ($TargetCallable -is [string]) {
            try {
                $TargetCallable = Get-Command `
                    -Name $TargetCallable `
                    -CommandType Function, Cmdlet `
                    -ErrorAction Stop
            } catch {
                throw "Failed to resolve command: $TargetCallable"
            }
        }

        Assert-CallableSignature `
            -Callable $TargetCallable `
            -RequiredParams 'ScriptBlockAst' `
            -ErrorAction Stop

        $this.Category = 'Other'
        if ($TargetCallable -is [scriptblock]) {
            $this.CallableType = 'ScriptBlock'
            $this.Callable = $TargetCallable
        } else {
            $this.Name = if ($TargetCallable.Noun) {
                $TargetCallable.Noun
            } else {
                $TargetCallable.Name
            }
            $this.CallableType = 'Function'
            $this.Callable = $TargetCallable
            $this.Source = $TargetCallable.ModuleName
        }

        $HasDetails = $TargetCallable |
            Get-CallableParameter -Name 'Details' -Type 'SwitchParameter'

        if ($HasDetails) {
            $Details = & $TargetCallable -Details
            foreach ($Property in 'Name', 'Category', 'Source', 'Description', 'Severity', 'Explanation') {
                if ($null -ne $Details.$Property) {
                    $this.$Property = $Details.$Property
                }
            }
        }

        foreach ($Property in 'Name', 'Category', 'Source', 'Description', 'Severity', 'Explanation') {
            if ($Overrides.ContainsKey($Property)) {
                $this.$Property = $Overrides[$Property]
            }
        }

        if ($TargetCallable -is [scriptblock] -and (-not $this.Name -or -not $this.Source)) {
            throw 'Name and Source are mandatory when using a scriptblock.'
        }
        if ($TargetCallable -isnot [scriptblock] -and -not $this.Source) {
            throw 'Source is mandatory for non-module functions/cmdlets.'
        }
    }

    # This could return a NitpickFinding or a DiagnosticRecord
    [object] Invoke([ScriptBlockAst] $Ast) {
        $PreviousInvocationContext = Get-Variable `
            -Name NitpickInvocationContext `
            -Scope Script `
            -ErrorAction SilentlyContinue
        $PreviousInvocationContextValue = $PreviousInvocationContext.Value
        try {
            $script:NitpickInvocationContext = 'Nitpick'
            return & $this.Callable -ScriptBlockAst $Ast
        } finally {
            if ($null -ne $PreviousInvocationContext) {
                $script:NitpickInvocationContext = $PreviousInvocationContextValue
            } else {
                Remove-Variable `
                    -Name NitpickInvocationContext `
                    -Scope Script `
                    -ErrorAction SilentlyContinue
            }
        }
    }
}

Update-TypeData `
    -TypeName 'NitpickRule' `
    -DefaultDisplayPropertySet 'Name', 'Category', 'Severity', 'Description' `
    -Force

# MARK: TRANSFORM

# NOTE: PowerShell's `Attribute` suffix omission happens during parse-time type resolution,
# and because this class lives in a separately parsed file. Without colocating the class,
# which is anti-DRY, the `Attribute` suffix must either be included or omitted so an exact
# type lookup can be performed. In this case, I'm choosing to omit the suffix in favor of a
# nicer decorator name.
class ScriptBlockAstTransform : ArgumentTransformationAttribute {
    [object] Transform([EngineIntrinsics] $EngineIntrinsics, [object] $Input) {
        if ($Input -is [ScriptBlock]) {
            return $Input.Ast
        }
        if ($Input -is [string]) {
            return [System.Management.Automation.Language.Parser]::ParseInput($Input, [ref] $null, [ref] $null)
        }
        return $Input
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


# Register built-in rules
# Get-ChildItem -Path "$ModuleRoot/Public/Rules" -Recurse -Filter '*.ps1' |
#     ForEach-Object {
#         Register-Nitpick -
#     }
