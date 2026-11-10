using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

<#
.SYNOPSIS
    Constructs an isolated rule context from plain data and the submitted target.

.DESCRIPTION
    Preserves legacy Caller, File, and partial RuleBehavior values. Adds empty
    or normalized Policy, file/fragment identity, and the actual analysis-host
    version. Reserved metadata is validated; AST file provenance is not file
    identity. Caller input and attached ETS members are never retained.

.EXAMPLE
    $Context = New-NitpickInvocationContext -Target { Get-Process }.Ast
    $Context.TargetKind
    $Context.Policy.Count

    Returns Fragment and 0. No project minimum is inferred from the host, whose
    version is recorded separately in AnalysisHost.PowerShellVersion.

.EXAMPLE
    $Document = New-AstDocument -Path '.\Example.ps1'
    $Policy = Read-NitpickConfiguration -LiteralPath '.\nitpick.psd1'
    $Context = New-NitpickInvocationContext -Target $Document -Context @{
        Caller = 'Build'
        Policy = $Policy
        RuleBehavior = @{ OutputType = 'DiagnosticRecord' }
    }

    Constructs a file-target context using an existing source file and policy
    file. TargetPath is absolute, policy is isolated, and the explicit partial
    RuleBehavior dictionary is preserved without adding traversal defaults.

.NOTES
    Private helper; examples run within Nitpick's module scope.
#>
function New-NitpickInvocationContext {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [object] $Target,

        [AllowNull()]
        [object] $Context
    )

    try {
        if ($null -eq $Context) { $Context = @{} }
        if ($Context -isnot [IDictionary]) {
            throw [ArgumentException]::new('Context must be a dictionary.')
        }

        $Copy = Copy-NitpickContextValue -Value $Context
        $IsDocument = $Target.GetType().Name -eq 'AstDocument'
        $Ast = if ($IsDocument) { $Target.Ast } else { $Target }

        if ($Ast -isnot [ScriptBlockAst]) {
            throw [ArgumentException]::new(
                'Context target must be an AstDocument or ScriptBlockAst.'
            )
        }

        $Kind = 'Fragment'
        $TargetPath = $null
        $HostVersion = [version] $PSVersionTable.PSVersion

        if ($IsDocument -and $Target.IsFileBacked) {
            $Kind = 'File'
            $TargetPath = [IO.Path]::GetFullPath($Target.Path)
        }

        if ($Copy.ContainsKey('TargetKind') -and (
            $Copy.TargetKind -isnot [string] -or
            $Copy.TargetKind -cne $Kind)
        ) {
            throw [ArgumentException]::new(
                "Context.TargetKind must match the submitted target ('$Kind')."
            )
        }

        if ($Copy.ContainsKey('TargetPath') -and (
            ($null -ne $Copy.TargetPath -and
            $Copy.TargetPath -isnot [string]) -or
            $Copy.TargetPath -ne $TargetPath)
        ) {
            throw [ArgumentException]::new(
                'Context.TargetPath must match the submitted target.'
            )
        }

        if ($Copy.ContainsKey('AnalysisHost')) {
            if ($Copy.AnalysisHost -isnot [IDictionary] -or
                $Copy.AnalysisHost.psbase.Count -ne 1 -or
                -not $Copy.AnalysisHost.Contains('PowerShellVersion') -or
                $Copy.AnalysisHost.PowerShellVersion -isnot [version] -or
                $Copy.AnalysisHost.PowerShellVersion -ne $HostVersion
            ) {
                throw [ArgumentException]::new(
                    'Context.AnalysisHost must describe the actual PowerShellVersion.'
                )
            }
        }

        if ($Copy.ContainsKey('Policy')) {
            $Copy.Policy = ConvertTo-NitpickPolicy -Policy $Copy.Policy -AllowVersion
        } else {
            $Copy.Policy = @{}
        }

        if (-not $Copy.ContainsKey('Caller')) { $Copy.Caller = 'Nitpick' }
        if (-not $Copy.ContainsKey('File')) { $Copy.File = $Ast.Extent.File }
        if ($null -eq $Copy.RuleBehavior) {
            $Copy.RuleBehavior = @{
                SearchNestedScriptBlocks = $true
                OutputType = 'NitpickFinding'
            }
        }

        $Copy.TargetKind = $Kind
        $Copy.TargetPath = $TargetPath
        $Copy.AnalysisHost = @{ PowerShellVersion = [version]::new($HostVersion.ToString()) }

        return $Copy
    } catch {
        $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new(
            $_.Exception, 'NitpickInvalidContext',
            [ErrorCategory]::InvalidData,
            'Context'
        ))
    }
}
