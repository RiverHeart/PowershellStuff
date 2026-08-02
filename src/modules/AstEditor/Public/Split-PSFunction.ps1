<#
.SYNOPSIS
    Previews or applies splitting top-level functions into individual files.

.DESCRIPTION
    Extracts selected top-level functions, or every top-level function when Name is
    omitted, into files named after each function. The source and destination files
    are changed only when Apply is specified.
#>
function Split-PSFunction {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $OutputDirectory,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]] $Name,

        [switch] $ExcludeHelp,

        [switch] $Apply,

        [switch] $Force
    )

    $Document = New-AstDocument -Path $Path
    if ($Document.ParseErrors.Count -gt 0) {
        throw "Cannot extract functions from a document with $($Document.ParseErrors.Count) existing parse error(s)."
    }

    if (-not $PSBoundParameters.ContainsKey('Name')) {
        $DiscoveredFunctions = @(
            $Document.Ast.FindAll({
                param($Node)

                if ($Node -isnot [FunctionDefinitionAst]) {
                    return $false
                }

                $Ancestor = $Node.Parent
                while ($null -ne $Ancestor) {
                    if ($Ancestor -is [FunctionDefinitionAst] -or $Ancestor -is [TypeDefinitionAst]) {
                        return $false
                    }
                    $Ancestor = $Ancestor.Parent
                }

                return $true
            }, $true)
        )
        $Name = @($DiscoveredFunctions |
            ForEach-Object -MemberName Name -WhatIf:$false)
    }

    if ($Name.Count -eq 0) {
        throw 'No top-level functions were found to extract.'
    }

    $ResolvedOutputDirectory = [Path]::GetFullPath($OutputDirectory)
    $Files = [List[object]]::new()
    $DestinationNames = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($FunctionName in $Name) {
        $Plan = Extract-AstFunction `
            -Document $Document `
            -Name $FunctionName `
            -ExcludeHelp:$ExcludeHelp
        $DestinationPath = Join-Path $ResolvedOutputDirectory "$($Plan.Name).ps1"
        if (-not $DestinationNames.Add($DestinationPath)) {
            throw "More than one extracted function maps to '$DestinationPath'."
        }

        $Files.Add([pscustomobject] @{
            Name = $Plan.Name
            Path = $DestinationPath
            Text = $Plan.Text
            IncludedHelp = $Plan.IncludedHelp
        })
    }

    $Validation = Resolve-AstDocument -Document $Document -PassThruText
    if ($Validation.ParseErrorCount -gt 0) {
        throw "Cannot extract functions. The remaining source has $($Validation.ParseErrorCount) parse error(s)."
    }

    $Applied = $false
    if ($Apply) {
        foreach ($File in $Files) {
            if ((Test-Path -LiteralPath $File.Path) -and -not $Force) {
                throw "Destination file '$($File.Path)' already exists. Use Force to overwrite it."
            }
        }

        if ($PSCmdlet.ShouldProcess($Document.Path, "Extract $($Files.Count) function(s) to '$ResolvedOutputDirectory'")) {
            [Directory]::CreateDirectory($ResolvedOutputDirectory) | Out-Null
            foreach ($File in $Files) {
                [File]::WriteAllText($File.Path, $File.Text)
            }
            [File]::WriteAllText($Document.Path, $Validation.RenderedText)
            $Applied = $true
        }
    }

    return [pscustomobject] @{
        Path = $Document.Path
        OutputDirectory = $ResolvedOutputDirectory
        Files = $Files.ToArray()
        Applied = $Applied
        EditCount = $Validation.EditCount
        ParseErrorCount = $Validation.ParseErrorCount
        ParseErrors = $Validation.ParseErrors
        RenderedText = $Validation.RenderedText
        Diff = Show-AstDiff -Document $Document
        Document = $Document
    }
}
