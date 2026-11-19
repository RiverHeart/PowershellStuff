using namespace System.Collections
using namespace System.Management.Automation.Language
using module AstEditor

<#
.SYNOPSIS
    PSScriptAnalyzer adapter for the native line-length rule.

.DESCRIPTION
    Converts the supplied ScriptBlockAst to an AstDocument and delegates to
    Measure-AvoidLongLines.
#>
function Test-AvoidLongLines {
    [CmdletBinding(DefaultParameterSetName='ScriptBlockAst')]
    [OutputType([object[]], [hashtable])]
    param(
        [Parameter(Mandatory,ParameterSetName='ScriptBlockAst')]
        [ValidateNotNullOrEmpty()]
        [ScriptBlockAst] $ScriptBlockAst,

        [Parameter(ParameterSetName='ScriptBlockAst')]
        [IDictionary] $Context,

        [Parameter(Mandatory,ParameterSetName='Details')]
        [switch] $Details
    )

    if ($Details) {
        return Measure-AvoidLongLines -Details
    }

    $Document = New-AstDocument -InputObject $ScriptBlockAst
    Measure-AvoidLongLines -InputObject $Document -Context $Context
}

<#
.SYNOPSIS
    Finds physical source lines that exceed the configured length.

.DESCRIPTION
    Counts UTF-16 code units in each physical snapshot line, excluding its line
    terminator. For fragments, a complete physical line is measured when it
    intersects the submitted fragment, while the finding extent remains inside
    that fragment. Findings are detection-only.

.PARAMETER InputObject
    The complete source snapshot and parsed metadata to analyze.

.PARAMETER Context
    Optional invocation context. RuleSettings.MaximumLength overrides the
    default of 120. RuleBehavior.OutputType selects NitpickFinding or
    DiagnosticRecord output.
#>
function Measure-AvoidLongLines {
    [CmdletBinding(DefaultParameterSetName='Document')]
    [OutputType([object[]], [hashtable])]
    param(
        [Parameter(Mandatory,ParameterSetName='Document',ValueFromPipeline)]
        [AstDocument] $InputObject,

        [Parameter(ParameterSetName='Document')]
        [IDictionary] $Context,

        [Parameter(Mandatory,ParameterSetName='Details')]
        [switch] $Details
    )

    begin {
        $Command = $PSCmdlet.MyInvocation.MyCommand
        $RuleName = if ($Command.Noun) { $Command.Noun } else { $Command.Name }
        $RuleId = "Nitpick/$RuleName"
        $SettingsSchema = @{
            MaximumLength = @{
                Type = 'Integer'
                Default = 120
                Minimum = 1
            }
        }
        $Metadata = @{
            Name = $RuleName
            CommandName = $Command.Name
            Category = 'Style'
            Description = 'Detects physical lines that exceed a configured length.'
            Severity = 'Warning'
            Explanation = 'Keep physical lines within the configured maximum length.'
            Settings = $SettingsSchema
        }
    }

    process {
        if ($Details) { return $Metadata }

        $RuleBehavior = $Context.RuleBehavior
        $OutputAs = if ($null -eq $RuleBehavior.OutputType) {
            'DiagnosticRecord'
        } else {
            $RuleBehavior.OutputType
        }

        $SettingsInput = if ($null -ne $Context -and $Context.Contains('RuleSettings')) {
            $Context.RuleSettings
        } else {
            @{}
        }

        $EffectiveSettings = ConvertTo-NitpickEffectiveRuleSettings `
            -Schema (ConvertTo-NitpickRuleSettingsSchema -Settings $SettingsSchema -RuleId $RuleId) `
            -Values $SettingsInput `
            -RuleId $RuleId `
            -ErrorAction Stop

        $MaximumLength = $EffectiveSettings.MaximumLength
        $Document = $InputObject
        $Text = $Document.OriginalText
        $FragmentStart = if ($Document.IsFragment) { $Document.Ast.Extent.StartOffset } else { 0 }
        $FragmentEnd = if ($Document.IsFragment) { $Document.Ast.Extent.EndOffset } else { $Text.Length }
        $FilePath = if ($Document.Ast.Extent.File) {
            $Document.Ast.Extent.File
        } else {
            '<ScriptBlock>'
        }

        $LineStart = 0
        $Offset = 0
        while ($Offset -lt $Text.Length) {
            if ($Text[$Offset] -notin [char] 13, [char] 10) {
                $Offset++
                continue
            }

            $LineEnd = $Offset
            $LineBreakEnd = $Offset + 1
            if ($Text[$Offset] -eq [char] 13 -and
                $LineBreakEnd -lt $Text.Length -and
                $Text[$LineBreakEnd] -eq [char] 10
            ) {
                $LineBreakEnd++
            }

            New-AvoidLongLinesFinding `
                -Document $Document `
                -RuleId $RuleId `
                -FilePath $FilePath `
                -Text $Text `
                -LineStart $LineStart `
                -LineEnd $LineEnd `
                -LineBreakEnd $LineBreakEnd `
                -FragmentStart $FragmentStart `
                -FragmentEnd $FragmentEnd `
                -MaximumLength $MaximumLength `
                -OutputAs $OutputAs

            $Offset = $LineBreakEnd
            $LineStart = $LineBreakEnd
        }

        if ($LineStart -lt $Text.Length) {
            New-AvoidLongLinesFinding `
                -Document $Document `
                -RuleId $RuleId `
                -FilePath $FilePath `
                -Text $Text `
                -LineStart $LineStart `
                -LineEnd $Text.Length `
                -LineBreakEnd $Text.Length `
                -FragmentStart $FragmentStart `
                -FragmentEnd $FragmentEnd `
                -MaximumLength $MaximumLength `
                -OutputAs $OutputAs
        }
    }
}

function New-AvoidLongLinesFinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AstDocument] $Document,

        [Parameter(Mandatory)]
        [string] $RuleId,

        [Parameter(Mandatory)]
        [string] $FilePath,

        [Parameter(Mandatory)]
        [string] $Text,

        [Parameter(Mandatory)]
        [int] $LineStart,

        [Parameter(Mandatory)]
        [int] $LineEnd,

        [Parameter(Mandatory)]
        [int] $LineBreakEnd,

        [Parameter(Mandatory)]
        [int] $FragmentStart,

        [Parameter(Mandatory)]
        [int] $FragmentEnd,

        [Parameter(Mandatory)]
        [int] $MaximumLength,

        [Parameter(Mandatory)]
        [string] $OutputAs
    )

    $LineLength = $LineEnd - $LineStart
    if ($LineLength -le $MaximumLength) { return }

    $ExtentStart = $LineStart
    $ExtentEnd = $LineEnd
    if ($Document.IsFragment) {
        $ExtentStart = [Math]::Max($LineStart, $FragmentStart)
        $ExtentEnd = [Math]::Min($LineEnd, $FragmentEnd)

        if ($ExtentStart -ge $ExtentEnd) {
            $IntersectionStart = [Math]::Max($LineStart, $FragmentStart)
            $IntersectionEnd = [Math]::Min($LineBreakEnd, $FragmentEnd)
            if ($IntersectionStart -ge $IntersectionEnd) { return }

            $ExtentStart = $IntersectionStart
            $ExtentEnd = $IntersectionStart + 1
        }
    }

    $Extent = New-AstScriptExtent `
        -Document $Document `
        -StartOffset $ExtentStart `
        -EndOffset $ExtentEnd

    New-NitpickFinding `
        -RuleId $RuleId `
        -Message "Line has $LineLength UTF-16 code units; maximum is $MaximumLength." `
        -ViolationExtent $Extent `
        -Severity Warning `
        -Corrections @() `
        -ScriptPath $FilePath `
        -Explanation 'The physical source line exceeds the configured maximum length.' `
        -OutputAs $OutputAs
}
