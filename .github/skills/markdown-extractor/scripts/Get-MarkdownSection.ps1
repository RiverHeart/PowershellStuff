using namespace System.Collections.Generic
using namespace System.IO

class MarkdownDocument {
    [List[MarkdownSection]] $Sections = [List[MarkdownSection]]::new()
    [List[string]] $Preamble = [List[string]]::new()
    [FileInfo] $FileInfo
    hidden [bool] $HasFinalNewline

    MarkdownDocument() {}

    [void] ParseFile([string] $Path) {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw [FileNotFoundException]::new("File not found: $Path", $Path)
        }

        $ResolvedPath = Resolve-Path -LiteralPath $Path -ErrorAction Stop
        $File = Get-Item -LiteralPath $ResolvedPath.Path -ErrorAction Stop
        $Reader = [StreamReader]::new($File.FullName)
        try {
            $this.ParseStream($Reader)
            $this.FileInfo = $File
        } finally {
            $Reader.Dispose()
        }
    }

    [void] ParseString([string] $String) {
        $Reader = [StringReader]::new($String)
        try {
            $this.ParseStream($Reader)
        } finally {
            $Reader.Dispose()
        }
    }

    [void] ParseStream([TextReader] $Reader) {
        $this.ParseStream($Reader, 0)
    }

    [void] ParseStream([TextReader] $Reader, [int] $MaxDepth) {
        if ($MaxDepth -lt 0 -or $MaxDepth -gt 6) {
            throw [System.ArgumentOutOfRangeException]::new('MaxDepth', 'Use 0 for all headings, or a depth from 1 to 6.')
        }
        if ($null -eq $Reader) {
            throw [System.ArgumentNullException]::new('Reader')
        }

        $SourceText = $Reader.ReadToEnd()
        $this.HasFinalNewline = $SourceText.EndsWith("`n") -or $SourceText.EndsWith("`r")
        $this.Sections = [List[MarkdownSection]]::new()
        $this.Preamble = [List[string]]::new()
        $this.FileInfo = $null
        $State = @{
            Line = $null
            LineNumber = 0
            InCodeFence = $false
        }
        $ParserReader = [StringReader]::new($SourceText)

        try {
            $this.ReadNextLine($ParserReader, $State)
            while ($null -ne $State.Line) {
                $Depth = $this.GetHeaderDepth($State)
                if ($Depth -gt 0 -and ($MaxDepth -eq 0 -or $Depth -le $MaxDepth)) {
                    $this.Sections.Add($this.ReadSection($ParserReader, $State, $MaxDepth))
                } else {
                    $this.Preamble.Add($State.Line)
                    $this.ReadNextLine($ParserReader, $State)
                }
            }
        } finally {
            $ParserReader.Dispose()
        }
    }

    hidden [void] ReadNextLine([TextReader] $Reader, [hashtable] $State) {
        if ($State.Line -match '^\s*```') {
            $State.InCodeFence = -not $State.InCodeFence
        }
        $State.Line = $Reader.ReadLine()
        $State.LineNumber++
    }

    hidden [int] GetHeaderDepth([hashtable] $State) {
        if (-not $State.InCodeFence -and $State.Line -match '^(#{1,6})\s+.+$') {
            return $Matches[1].Length
        }
        return 0
    }

    hidden [MarkdownSection] ReadSection([TextReader] $Reader, [hashtable] $State, [int] $MaxDepth) {
        $Depth = $this.GetHeaderDepth($State)
        $Header = $State.Line
        $Slug = $Header.ToLowerInvariant().Replace('#', '').Trim() `
            -replace '\s+', '-' `
            -replace '[^a-zA-Z0-9-]', ''
        $Result = [MarkdownSection]::new($Header, $Slug, $State.LineNumber + 1)
        $Result.Depth = $Depth
        $this.ReadNextLine($Reader, $State)

        while ($null -ne $State.Line) {
            $NextDepth = $this.GetHeaderDepth($State)
            if ($NextDepth -gt 0 -and $NextDepth -le $Depth) {
                # Leave the next sibling or ancestor heading for the calling frame.
                break
            }
            if ($NextDepth -gt $Depth -and ($MaxDepth -eq 0 -or $NextDepth -le $MaxDepth)) {
                $Child = $this.ReadSection($Reader, $State, $MaxDepth)
                $Result.Sections.Add($Child)
            } else {
                $Result.Content.Add($State.Line)
                $this.ReadNextLine($Reader, $State)
            }
        }

        $Result.LineEnd = $Result.LineStart + $Result.Content.Count - 1
        return $Result
    }

    [MarkdownSection[]] GetSections() {
        $Result = [List[MarkdownSection]]::new()
        $this.AddSections($this.Sections, $Result)
        return $Result.ToArray()
    }

    hidden [void] AddSections([List[MarkdownSection]] $Sections, [List[MarkdownSection]] $Result) {
        foreach ($Item in $Sections) {
            $Result.Add($Item)
            $this.AddSections($Item.Sections, $Result)
        }
    }

    [void] Save([string] $Path) {
        [File]::WriteAllText($Path, $this.ToString())
    }

    [string] ToString() {
        $Lines = [List[string]]::new()
        $Lines.AddRange($this.Preamble)
        foreach ($Item in $this.Sections) {
            $Item.AppendLines($Lines, $true)
        }
        $Text = $Lines -join [Environment]::NewLine
        if ($this.HasFinalNewline -and $Lines.Count -gt 0) {
            $Text += [Environment]::NewLine
        }
        return $Text
    }
}

class MarkdownSection {
    [string] $Header
    [string] $Section
    [int] $Depth
    [int] $LineStart
    [int] $LineEnd
    [List[string]] $Content
    [List[MarkdownSection]] $Sections

    MarkdownSection() {
        $this.Content = [List[string]]::new()
        $this.Sections = [List[MarkdownSection]]::new()
    }

    MarkdownSection([string] $Header, [string] $Section, [int] $LineStart) {
        $this.Header = $Header
        $this.Section = $Section
        $this.LineStart = $LineStart
        $this.LineEnd = $null
        $this.Content = [List[string]]::new()
        $this.Sections = [List[MarkdownSection]]::new()
    }

    [string[]] GetContent() {
        $Lines = [List[string]]::new()
        $this.AppendLines($Lines, $false)
        return $Lines.ToArray()
    }

    hidden [void] AppendLines([List[string]] $Lines, [bool] $IncludeHeader) {
        if ($IncludeHeader) {
            $Lines.Add($this.Header)
        }
        $Lines.AddRange($this.Content)
        foreach ($Child in $this.Sections) {
            $Child.AppendLines($Lines, $true)
        }
    }
}

Update-TypeData `
    -TypeName 'MarkdownSection' `
    -MemberType ScriptProperty `
    -MemberName ContentLineCount `
    -Value { $this.Content.Count } `
    -Force

Update-TypeData `
    -TypeName 'MarkdownSection' `
    -DefaultDisplayPropertySet Header, Section, LineStart, LineEnd, ContentLineCount `
    -Force

<#
.SYNOPSIS
    Parses Markdown into one document containing a hierarchy of sections.

.DESCRIPTION
    Sections contains top-level headings; each section has its own child Sections.
    Content stores only direct body lines, up to the next heading. GetContent()
    recursively includes descendant headings and bodies. GetSections() returns all
    sections in document order. ToString() and Save() serialize the current tree,
    including edits, with platform newlines. Preamble stores lines before the first heading.

.EXAMPLE
    $Document = New-MarkdownDocument -Path .\README.md
    $Document.Sections

.EXAMPLE
    New-MarkdownDocument -Text "# Title`nBody"
#>
function New-MarkdownDocument {
    [CmdletBinding(DefaultParameterSetName='Path')]
    [OutputType([MarkdownDocument])]
    param (
        [Parameter(Mandatory, ParameterSetName='Path', ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory, ParameterSetName='Text')]
        [AllowEmptyString()]
        [string] $Text
    )

    process {
        $Document = [MarkdownDocument]::new()
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            $Document.ParseFile($Path)
        } else {
            $Document.ParseString($Text)
        }
        $Document
    }
}

<#
.SYNOPSIS
    Extracts the content of a specified section from a Markdown file. The section is
    identified by its header (e.g., "# Section Name").

.DESCRIPTION
    Parses a Markdown file into section objects identified by header slug.

    By default, returns all section objects. When -Section is provided, the output is
    filtered to matching section slug values. Use -Name to return only slugs,
    -Content to return line output, and -RawContent to return a single text block.
    Content and RawContent output include descendant headings and bodies, ending at the
    next heading of equal or shallower depth. Returned section objects store only direct
    body lines in Content. Use New-MarkdownDocument for hierarchical output and editing.

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
    [OutputType([string], [MarkdownSection])]
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

    process {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            Write-Error -Message "File not found: $Path" -Category ObjectNotFound
            return
        }

        $Markdown = New-MarkdownDocument -Path $Path
        $OutputSections = @($Markdown.GetSections())

        if ($PSBoundParameters.ContainsKey('Section')) {
            $OutputSections = @($OutputSections | Where-Object { $_.Section -eq $Section })

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
                Write-Output ($OutputSection.GetContent())
            }

            return
        }

        if ($RawContent) {
            foreach ($OutputSection in $OutputSections) {
                Write-Output ($OutputSection.GetContent() -join [Environment]::NewLine)
            }

            return
        }

        Write-Output $OutputSections
    }
}
