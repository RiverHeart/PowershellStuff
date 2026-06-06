<#
.SYNOPSIS
    Extracts the content of a specified section from a Markdown file. The section is
    identified by its header (e.g., "# Section Name").

.DESCRIPTION
    Parses a Markdown file into section objects identified by header slug.

    By default, returns all section objects. When -Section is provided, the output is
    filtered to matching section slug values. Use -Name to return only slugs,
    -Content to return line output, and -RawContent to return a single text block.

    To prevent console clutter, section content is not included in the default output.
    Instead, use the -Content or -RawContent parameters to include content in the output.

.NOTES
    This script was designed to assist agents in extracting sections from Markdown files
    without needing to read the entire file.

.EXAMPLE
    Get-MarkdownSection -Path .\README.md

    Returns all discovered markdown sections as objects. Default formatting shows
    Section, LineStart, LineEnd, and ContentLineCount.

.EXAMPLE
    Get-MarkdownSection -Path .\README.md -Section why-use-it

    Filters the returned section objects to a specific slug.

.EXAMPLE
    Get-MarkdownSection -Path .\README.md -Name

    Returns only section slugs.

.EXAMPLE
    Get-MarkdownSection -Path .\README.md -Section why-use-it -Content

    Returns only the content lines for the matching section slug.

.EXAMPLE
    Get-MarkdownSection -Path .\README.md -Section why-use-it -RawContent

    Returns section content as a single string separated by newlines.

.EXAMPLE
    Get-MarkdownSection -Path .\README.md -Section overview -Name

    Returns only the slug value for the filtered section.

.EXAMPLE
    [pscustomobject]@{ Path = '.\README.md' } | Get-MarkdownSection -Name

    Uses ValueFromPipelineByPropertyName for Path.
#>
function Get-MarkdownSection {
    [CmdletBinding(DefaultParameterSetName='Object')]
    [OutputType([string], [pscustomobject])]
    param(
        [Parameter(Mandatory, ParameterSetName='Object', ValueFromPipelineByPropertyName)]
        [Parameter(Mandatory, ParameterSetName='Name', ValueFromPipelineByPropertyName)]
        [Parameter(Mandatory, ParameterSetName='Content', ValueFromPipelineByPropertyName)]
        [Parameter(Mandatory, ParameterSetName='RawContent', ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(ParameterSetName='Object')]
        [Parameter(ParameterSetName='Name')]
        [Parameter(Mandatory, ParameterSetName='Content')]
        [Parameter(Mandatory, ParameterSetName='RawContent')]
        [ValidateNotNullOrEmpty()]
        [string] $Section,

        [Parameter(ParameterSetName='Name')]
        [switch] $Name,

        [Parameter(ParameterSetName='Content')]
        [switch] $Content,

        [Parameter(ParameterSetName='RawContent')]
        [switch] $RawContent
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Error -Message "File not found: $Path" -Category ObjectNotFound
        return
    }

    $ResolvedPath = Convert-Path -LiteralPath $Path
    $SectionList = [System.Collections.Generic.List[psobject]]::new()

    Update-TypeData -TypeName 'Markdown.SectionInfo' -DefaultDisplayPropertySet Section, LineStart, LineEnd, ContentLineCount -Force

    $InCodeFence = $false
    $LineNumber = 0
    $CurrentSection = $null
    $Reader = $null
    try {
        $Reader = [System.IO.StreamReader]::new($ResolvedPath)

        while (-not $Reader.EndOfStream) {
            $Line = $Reader.ReadLine()
            $LineNumber++

            if (-not $InCodeFence -and $Line -match '^(#{1,6}\s+.+)$') {
                if ($CurrentSection) {
                    $CurrentSection.LineEnd = $LineNumber - 1
                    $CurrentSection.ContentLineCount = $CurrentSection.Content.Count
                    $SectionList.Add($CurrentSection)
                }

                $HeaderText = $Matches[1].Trim()
                $HeaderSlug =
                    $HeaderText.ToLowerInvariant().Replace('#', '').Trim() `
                    -replace '\s+', '-' `
                    -replace '[^a-zA-Z0-9-]', ''

                $CurrentSection = [pscustomobject]@{
                    PSTypeName = 'Markdown.SectionInfo'
                    Header    = $HeaderText
                    Section   = $HeaderSlug
                    LineStart = $LineNumber + 1
                    LineEnd   = $null
                    ContentLineCount = $null
                    Content   = [System.Collections.Generic.List[string]]::new()
                }

                continue
            }

            if ($CurrentSection) {
                $CurrentSection.Content.Add($Line)
            }

            if ($Line -match '^\s*```') {
                $InCodeFence = -not $InCodeFence
            }
        }

        if ($CurrentSection) {
            $CurrentSection.LineEnd = $LineNumber
            $CurrentSection.ContentLineCount = $CurrentSection.Content.Count
            $SectionList.Add($CurrentSection)
        }
    } finally {
        if ($Reader) { $Reader.Close() }
    }

    $OutputSections = $SectionList
    if ($PSBoundParameters.ContainsKey('Section')) {
        $OutputSections = @($SectionList | Where-Object { $_.Section -eq $Section })

        if ($OutputSections.Count -eq 0) {
            Write-Error -Message "Section not found: $Section" -Category ObjectNotFound
            return
        }

        if ($OutputSections.Count -gt 1) {
            Write-Warning "Found multiple sections with slug '$Section'. Returning the first match only."
            $OutputSections = @($OutputSections[0])
        }
    }

    if ($Name) {
        Write-Output $OutputSections.Section
        return
    }

    if ($Content) {
        foreach ($OutputSection in $OutputSections) {
            Write-Output $OutputSection.Content
        }

        return
    }

    if ($RawContent) {
        foreach ($OutputSection in $OutputSections) {
            Write-Output ($OutputSection.Content -join [Environment]::NewLine)
        }

        return
    }

    Write-Output $OutputSections
}
