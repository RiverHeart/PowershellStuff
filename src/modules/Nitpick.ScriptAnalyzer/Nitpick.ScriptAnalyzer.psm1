using namespace System.Collections
using namespace System.Collections.ObjectModel
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Converts one native Nitpick correction to a PSScriptAnalyzer correction.

.PARAMETER Correction
    The native NitpickCorrection to convert. Multi-edit corrections emit nothing.

.EXAMPLE
    ConvertTo-ScriptAnalyzerCorrectionExtent -Correction $Correction

    Returns a CorrectionExtent for a single-edit correction.

.NOTES
    Private adapter helper; examples run within the adapter module's scope.
#>
function ConvertTo-ScriptAnalyzerCorrectionExtent {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [object] $Correction
    )

    process {
        if ($Correction.GetType().Name -ne 'NitpickCorrection') {
            throw [ArgumentException]::new(
                'The adapter requires a NitpickCorrection.',
                'Correction'
            )
        }

        if ($Correction.TextEdits.Count -gt 1) {
            return
        }

        Write-Output (New-Object `
            -TypeName 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent' `
            -ArgumentList (
                $Correction.StartLineNumber,
                $Correction.EndLineNumber,
                $Correction.StartColumnNumber,
                $Correction.EndColumnNumber,
                $Correction.ReplacementText,
                $Correction.FilePathOrContext,
                $Correction.Description
            ))
    }
}

<#
.SYNOPSIS
    Converts one native Nitpick finding to a PSScriptAnalyzer diagnostic.

.PARAMETER Finding
    The native NitpickFinding to convert.

.EXAMPLE
    ConvertTo-ScriptAnalyzerDiagnosticRecord -Finding $Finding

    Returns a DiagnosticRecord with representable suggested corrections.

.NOTES
    Private adapter helper; examples run within the adapter module's scope.
#>
function ConvertTo-ScriptAnalyzerDiagnosticRecord {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [object] $Finding
    )

    process {
        if ($Finding.GetType().Name -ne 'NitpickFinding') {
            throw [InvalidOperationException]::new(
                "The adapter expected NitpickFinding output but received '$($Finding.GetType().FullName)'."
            )
        }

        $LocalName = $Finding.RuleId.Split('/')[1]
        $CorrectionExtents = New-Object `
            'System.Collections.ObjectModel.Collection[Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.CorrectionExtent]'

        foreach ($Correction in $Finding.Corrections) {
            if ($Correction.TextEdits.Count -gt 1) {
                continue
            }
            $CorrectionExtents.Add((ConvertTo-ScriptAnalyzerCorrectionExtent -Correction $Correction))
        }

        Write-Output (New-Object `
            -TypeName 'Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord' `
            -ArgumentList (
                $Finding.Message,
                $Finding.ViolationExtent,
                $LocalName,
                $Finding.Severity,
                $Finding.ViolationExtent.File,
                $LocalName,
                $CorrectionExtents.PSObject.BaseObject
            ))
    }
}

<#
.SYNOPSIS
    Provides the shared implementation for generated PSScriptAnalyzer wrappers.

.PARAMETER ScriptBlockAst
    The AST supplied by PSScriptAnalyzer.

.PARAMETER FilePath
    The optional source path supplied by PSScriptAnalyzer.

.PARAMETER Options
    Optional direct wrapper rule settings.

.PARAMETER Context
    Optional direct wrapper invocation data containing RuleSettings.

.PARAMETER Details
    Returns descriptor metadata instead of analyzing an AST.

.EXAMPLE
    Invoke-ScriptAnalyzerAdapterRule -ScriptBlockAst { $Value = 1 }.Ast

    Invokes the generated command's native Nitpick rule and returns diagnostics.

.NOTES
    Private adapter template; generated commands use this body.
#>
function Invoke-ScriptAnalyzerAdapterRule {
    [CmdletBinding(DefaultParameterSetName='ScriptBlockAst')]
    [OutputType([object[]], [pscustomobject])]
    param(
        [Parameter(Mandatory,ParameterSetName='ScriptBlockAst')]
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst] $ScriptBlockAst,

        [Parameter(ParameterSetName='ScriptBlockAst')]
        [string] $FilePath,

        [Parameter(ParameterSetName='ScriptBlockAst')]
        [IDictionary] $Options,

        [Parameter(ParameterSetName='ScriptBlockAst')]
        [IDictionary] $Context,

        [Parameter(Mandatory,ParameterSetName='Details')]
        [switch] $Details
    )

    $CommandName = $PSCmdlet.MyInvocation.MyCommand.Name
    $LocalName = $CommandName -replace '^Test-', ''
    $Rule = @(Find-Nitpick `
        -IncludeRule "Nitpick/$LocalName" `
        -ErrorAction Stop)
    if ($Rule.Count -ne 1) {
        throw [InvalidOperationException]::new(
            "Expected exactly one built-in Nitpick rule for adapter command '$CommandName', found $($Rule.Count)."
        )
    }
    $Rule = $Rule[0]

    if ($Details) {
        Write-Output $Rule
        return
    }

    $NativeContext = @{
        Caller = 'Nitpick.ScriptAnalyzer'
        File = if ($FilePath) { $FilePath } else { $ScriptBlockAst.Extent.File }
        RuleBehavior = @{
            SearchNestedScriptBlocks = $false
        }
    }

    if ($null -ne $Options) {
        $NativeContext.RuleSettings = $Options
    } elseif ($null -ne $Context -and $Context.Contains('RuleSettings')) {
        $NativeContext.RuleSettings = $Context.RuleSettings
    }

    foreach ($Finding in $Rule.Invoke($ScriptBlockAst, $NativeContext)) {
        $Diagnostic = & (Get-Module Nitpick.ScriptAnalyzer) {
            param ($NativeFinding)
            ConvertTo-ScriptAnalyzerDiagnosticRecord -Finding $NativeFinding
        } $Finding
        Write-Output $Diagnostic
    }
}

$GeneratedRuleNamesByName = @{}
$GeneratedRuleNames = foreach ($Rule in @(Find-Nitpick -ErrorAction Stop)) {
    $CommandName = "Test-$($Rule.Name)"
    if ($GeneratedRuleNamesByName.ContainsKey($CommandName)) {
        throw [InvalidOperationException]::new(
            "Multiple built-in Nitpick rules generate adapter command '$CommandName'."
        )
    }
    $GeneratedRuleNamesByName[$CommandName] = $true

    $Wrapper = [scriptblock]::Create(@"
<#
.SYNOPSIS
    $($Rule.Description)
.DESCRIPTION
    $($Rule.Explanation)
#>
${function:Invoke-ScriptAnalyzerAdapterRule}
"@)
    Set-Item -Path "Function:script:$CommandName" -Value $Wrapper
    Write-Output $CommandName
}

Export-ModuleMember -Function @($GeneratedRuleNames)
