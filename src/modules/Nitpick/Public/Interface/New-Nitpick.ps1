using namespace System.Management.Automation

<#
.SYNOPSIS
    Creates a new Nitpick rule.

.DESCRIPTION
    Creates a new Nitpick rule object with the specified properties.

.PARAMETER Namespace
    The rule's identity namespace. Defaults to Local for scriptblocks and commands
    without an implementing module, or to the implementing module's name.

.PARAMETER Applicability
    Optional ScriptBlock receiving one isolated IDictionary context argument.
    Must emit exactly one Boolean. False skips execution; errors terminate.
    Explicit null clears a declaration from Details.

.PARAMETER MinimumAnalysisHostVersion
    Optional positive major/minor System.Version required to analyze an applicable
    target. Checked after applicability, not during discovery. Explicit null clears
    a declaration from Details. This is separate from project syntax policy.

.PARAMETER Settings
    Optional integer settings schema. Each setting declares Type, Default, and
    optional Minimum and Maximum values. Explicit null clears a declaration from Details.

.EXAMPLE
    Create rule from a scriptblock

    $NitpickParams = @{
        Name = 'MyNitpick'
        Callable = { param($word) $word }
        Source = 'MyModule'
    }
    $Nitpick = New-Nitpick @NitpickParams

.EXAMPLE
    Create rule from a function

    $NitpickParams = @{
        Callable = 'Get-Command'
    }
    $Nitpick = New-Nitpick @NitpickParams

.EXAMPLE
    Create a rule that requires policy and, only when applicable, a 7.0 host.

    $NitpickParams = @{
        Name = 'ProjectRule'
        Source = 'Tests'
        Callable = { param($ScriptBlockAst) }
        Applicability = {
            param([System.Collections.IDictionary] $Context)
            $Context.Policy.Count -gt 0
        }
        MinimumAnalysisHostVersion = ([version] '7.0')
    }
    $Rule = New-Nitpick @NitpickParams
#>
function New-Nitpick {
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [ValidateScript({
            $_ -is [string] -or
            $_ -is [scriptblock] -or
            $_ -is [FunctionInfo] -or
            $_ -is [CmdletInfo]
        })]
        [object] $Callable,

        [ArgumentCompleter({ Complete-NitpickCategory $args })]
        [string] $Category = 'Other',

        [bool] $EditorEnabled = $true,

        [Parameter(HelpMessage='Optional scriptblock receiving one isolated IDictionary context argument. Must emit exactly one Boolean. False skips execution; errors terminate. Explicit null clears a declaration from Details.')]
        [AllowNull()]
        [object] $Applicability,

        [Parameter(HelpMessage='Optional minimum analysis host version. Explicit null clears a declaration from Details.')]
        [AllowNull()]
        [object] $MinimumAnalysisHostVersion,

        [Parameter(HelpMessage='Optional integer settings schema. Explicit null clears a declaration from Details.')]
        [AllowNull()]
        [object] $Settings,

        [Parameter(HelpMessage='The name of the nitpick. Mandatory only when using a scriptblock')]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(HelpMessage='The namespace of the nitpick. Defaults to Local for scriptblocks and commands without an implementing module, or to the implementing module''s name.')]
        [ValidateNotNullOrEmpty()]
        [string] $Namespace,

        [Parameter(HelpMessage='The source of the nitpick. Mandatory only when using a scriptblock')]
        [ValidateNotNullOrEmpty()]
        [string] $Source
    )

    begin {
        $Properties = @(
            'Name', 'Namespace', 'Category', 'EditorEnabled', 'Source',
            'Applicability', 'MinimumAnalysisHostVersion', 'Settings'
        )
    }

    process {
        $Overrides = @{}
        foreach ($Property in $Properties) {
            if ($PSBoundParameters.ContainsKey($Property)) {
                $Overrides[$Property] = $PSBoundParameters[$Property]
            }
        }

        Write-Output ([NitpickRule]::new($Callable, $Overrides))
    }
}
