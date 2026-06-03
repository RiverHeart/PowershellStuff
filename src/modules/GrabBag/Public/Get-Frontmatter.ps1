<#
.SYNOPSIS
    Extracts frontmatter metadata from a file.

.DESCRIPTION
    Extracts frontmatter metadata from a file.

    For hashtable output, the frontmatter content is parsed
    using the selected InputFormat.

    For string output, the raw frontmatter content is returned.

.EXAMPLE
    Parses key-value metadata from a PowerShell script using the default Powershell comment style.

    Get-Frontmatter -Path 'script.ps1' -InputFormat KeyValuePair

.EXAMPLE
    Parses key-value metadata from a YAML file using the default Yaml comment style.

    Get-Frontmatter -Path 'config.yaml' -InputFormat KeyValuePair
#>
function Get-Frontmatter {
    [CmdletBinding()]
    [OutputType([hashtable], [string], [pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(HelpMessage="Ingestion method for frontmatter content.")]
        [ValidateSet('KeyValuePair', 'Json', 'PowerShellData')]
        [string] $InputFormat = 'KeyValuePair',

        [Parameter(HelpMessage="Name of a built-in comment style or a custom comment style object.")]
        [object] $MetadataStyle,

        [Parameter(HelpMessage="Output format for frontmatter content.")]
        [ValidateSet('Hashtable', 'String')]
        [string] $OutputFormat = 'Hashtable',

        [ValidateNotNullOrEmpty()]
        [string] $Delimiter,

        [switch] $FailOnMissing
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Error "File not found at path: $Path" -Category FileNotFound
        return
    }

    $MetadataStyles = @{
        ForwardSlash = @{
            Name = 'ForwardSlash'
            Extensions = @('.js', '.ts', '.jsx', '.tsx', '.css', '.scss', '.html')
            Start = '/*'
            End = '*/'
        }
        Powershell = @{
            Name = 'Powershell'
            Extensions = @('.ps1', '.psm1', '.psd1')
            Start = '<#Metadata'
            End = '#>'
        }
        Yaml = @{
            Name = 'Yaml'
            Extensions = @('.yml', '.yaml')
            Start = '---'
            End = '---'
        }
    }

    if ($MetadataStyle -and $MetadataStyle -is [string]) {
        if ($MetadataStyles.ContainsKey($MetadataStyle)) {
            $SelectedStyle = $MetadataStyles[$MetadataStyle]
            $Start = $SelectedStyle.Start
            $End = $SelectedStyle.End
        } else {
            Write-Error "Unknown comment style: $MetadataStyle" -Category InvalidArgument
            return
        }
    } elseif ($MetadataStyle -and $MetadataStyle -is [hashtable]) {
        if ($MetadataStyle.ContainsKey('Start') -and
            $MetadataStyle.ContainsKey('End')) {
            if ([string]::IsNullOrWhiteSpace([string] $MetadataStyle.Start) -or
                [string]::IsNullOrWhiteSpace([string] $MetadataStyle.End)) {
                Write-Error "Custom style Start and End must be non-empty strings." -Category InvalidArgument
                return
            }

            $Start = $MetadataStyle.Start
            $End = $MetadataStyle.End
        } else {
            Write-Error "Custom style must include Start and End keys." -Category InvalidArgument
            return
        }
    } elseif ($MetadataStyle) {
        Write-Error "Invalid type for MetadataStyle: $($MetadataStyle.GetType().Name). Expected string or hashtable." -Category InvalidArgument
        return
    }

    if ([string]::IsNullOrEmpty($Start) -and
        [string]::IsNullOrEmpty($End)
    ) {
        # Infer style from file extension; default to Yaml style if unknown.
        $Extension = [System.IO.Path]::GetExtension($Path)
        $MatchedStyles = @($MetadataStyles.Values | Where-Object { $_.Extensions -contains $Extension })
        if ($MatchedStyles.Count -gt 0) {
            $MetadataStyle = $MatchedStyles[0]
            $Start = $MetadataStyle.Start
            $End = $MetadataStyle.End
        } else {
            $Start = $MetadataStyles.Yaml.Start
            $End = $MetadataStyles.Yaml.End
        }
    }

    Write-Debug "Using frontmatter style '$($MetadataStyle.Name)' with Start='$Start' and End='$End' for file: $Path"

    # Parse metadata from file frontmatter
    $InMetadata = $false
    $FoundEndMarker = $false
    $Lines = [System.IO.File]::ReadLines($Path)
    $StringBuilder = [System.Text.StringBuilder]::new()

    foreach ($Line in $Lines) {
        # Trim whitespace and potential BOM from the line
        $TrimmedLine = $Line.Trim().TrimStart([char] 0xFEFF)

        if (-not $InMetadata) {
            if ([string]::IsNullOrWhiteSpace($TrimmedLine)) {
                continue
            }

            if ($TrimmedLine -eq $Start) {
                $InMetadata = $true
            } else {
                # Stop parsing if we hit a non-comment line before starting metadata block
                break
            }
        } else {
            if ($TrimmedLine -eq $End) {
                $FoundEndMarker = $true
                break
            } else {
                $StringBuilder.AppendLine($Line) | Out-Null
            }
        }
    }

    if ($InMetadata -and -not $FoundEndMarker) {
        Write-Error "Frontmatter start marker was found, but end marker '$End' was not found in file: $Path" -Category InvalidData
        return
    }

    if ($StringBuilder.Length -eq 0) {
        if ($FailOnMissing) {
            Write-Error "No frontmatter metadata found in file: $Path" -Category NotFound
        }
        return
    }

    if ($OutputFormat -eq 'String') {
        return $StringBuilder.ToString()
    }

    try {
        $MetadataString = $StringBuilder.ToString()
        switch ($InputFormat) {
            'KeyValuePair' {
                if (-not $Delimiter) {
                    $Delimiter = if ($MetadataStyle.Name -eq 'Yaml') { ':' } else { '=' }
                }

                if ($PSEdition -eq 'Core') {
                    # In PSv6+, ConvertFrom-StringData supports custom delimiters
                    return ConvertFrom-StringData -StringData $MetadataString -Delimiter $Delimiter
                } else {
                    # For older versions, we need to replace the delimiter with a newline and rejoin lines
                    $AdjustedString = ($MetadataString -split [Environment]::NewLine) -replace "$Delimiter(.+)", '=$1' -join [Environment]::NewLine
                    return ConvertFrom-StringData -StringData $AdjustedString
                }
            }
            'Json' {
                return ConvertFrom-Json -InputObject $MetadataString
            }
            'PowerShellData' {
                $Tokens = $null
                $ParseErrors = $null
                $Ast = [System.Management.Automation.Language.Parser]::ParseInput(
                    $MetadataString,
                    [ref] $Tokens,
                    [ref] $ParseErrors
                )

                if ($ParseErrors -and $ParseErrors.Count -gt 0) {
                    throw "Failed to parse frontmatter as PowerShell data: $($ParseErrors[0].Message)"
                }

                # Get AST from frontmatter content
                $Data = $Ast.Find({
                    param($node)
                    $node -is [System.Management.Automation.Language.HashtableAst]
                }, $false)

                if ($null -eq $Data) {
                    throw "No valid PowerShell data found in frontmatter."
                } else {
                    return $Data.SafeGetValue()
                }
            }
        }
    } catch {
        Write-Error "Failed to parse frontmatter metadata with error: $_" -Category InvalidData
        return
    }
}
