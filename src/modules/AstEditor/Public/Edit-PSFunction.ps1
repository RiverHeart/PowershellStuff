<#
.SYNOPSIS
    Previews or applies replacement of one function in a PowerShell file.

.DESCRIPTION
    Creates an AstDocument, queues a validated function replacement, and returns
    structured diagnostics and a diff. The source file is changed only when Apply
    is specified. WhatIf and Confirm are supported for applied edits.

.EXAMPLE
    $Result = Edit-PSFunction `
        -InputObject { function foo { Write-Host foo } } `
        -Name foo `
        -Replacement 'function foo { Write-Host fubar }'

    $Result.RenderedText
#>
function Edit-PSFunction {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory, ParameterSetName = 'InputObject')]
        [ValidateNotNullOrEmpty()]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Replacement,

        [switch] $Recurse,

        [switch] $ExcludeHelp,

        [Parameter(ParameterSetName = 'Path')]
        [switch] $Apply
    )

    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        $Document = New-AstDocument -Path $Path
    } else {
        $Document = New-AstDocument -InputObject $InputObject
    }
    $PlanParameters = @{
        Document = $Document
        Name = $Name
        Replacement = $Replacement
        Recurse = $Recurse
        ExcludeHelp = $ExcludeHelp
    }
    $Plan = Set-AstFunction @PlanParameters
    $Validation = Resolve-AstDocument -Document $Document -PassThruText
    $Diff = Show-AstDiff -Document $Document
    $Applied = $false

    if ($Apply) {
        if ($Validation.ParseErrorCount -gt 0) {
            throw "Cannot apply function replacement. Parse errors detected: $($Validation.ParseErrorCount)."
        }

        if ($PSCmdlet.ShouldProcess($Document.Path, "Replace function '$Name'")) {
            Save-AstDocument -Document $Document -Confirm:$false
            $Applied = $true
        }
    }

    return [pscustomobject] @{
        Path = $Document.Path
        Name = $Plan.Name
        ReplacementName = $Plan.ReplacementName
        IncludedHelp = $Plan.IncludedHelp
        Applied = $Applied
        EditCount = $Validation.EditCount
        ParseErrorCount = $Validation.ParseErrorCount
        ParseErrors = $Validation.ParseErrors
        RenderedText = $Validation.RenderedText
        Diff = $Diff
        Document = $Document
    }
}