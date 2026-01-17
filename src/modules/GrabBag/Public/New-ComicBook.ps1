
function New-ComicBookPage {
    [CmdletBinding()]
    [OutputType([hashtable], [System.Xml.XmlDocument])]
    param(
        [ValidateSet(
            'FrontCover', 'InnerCover', 'RoundUp', 'Story', 'Advertisement', 'Editorial',
            'Letters', 'Preview', 'BackCover', 'Other', 'Deleted'
        )]
        [string] $Type = 'Story',
        [uint32] $ImageSize,
        [string] $Key,
        [string] $Bookmark,
        [int32] $ImageWidth = -1,
        [int32] $ImageHeight = 1,
        [switch] $DoublePage,
        [ValidateSet('Hashtable', 'XmlDocument')]
        [string] $OutputAs
    )

    # TODO: Support accepting hashtable array

    if ($OutputAs -eq 'XmlDocument') {
        $Result = [xml] @"
<ComicPageInfo>
  <Type>$Type</Type>
  <ImageSize>$ImageSize</ImageSize>
  <Key>$Key</Key>
  <Bookmark>$Bookmark</Bookmark>
  <ImageWidth>$ImageWidth</ImageWidth>
  <ImageHeight>$ImageHeight</ImageHeight>
  <DoublePage>$DoublePage</DoublePage>
<ComicPageInfo>
"@
    } else {
        $Result = @{
            Type = 'Story'
            ImageSize = $ImageSize
            Key = $Key
            Bookmark = $Bookmark
            ImageWidth = $ImageWidth
            ImageHeight = $ImageHeight
            DoublePage = $DoublePage
        }
    }

    return $Result
}

# https://anansi-project.github.io/docs/comicinfo/schemas/v2.0
function New-ComicBook {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void], [System.IO.FileInfo])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ImageFolder,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Title,

        [ValidateNotNullOrEmpty()]
        [string] $Series,

        [datetime] $ReleaseDate = [datetime]::Today,
        [string] $Publisher,
        [uint32] $IssueNumber,
        [uint32] $VolumeNumber,
        [uint32] $VolumesAvailable,
        [string] $Summary,
        [string] $Genre,
        [string] $LanguageISO = 'en',
        [string] $BindingFormat,
        [string[]] $Characters,
        [string[]] $Teams,
        [string[]] $Locations,
        [uint32] $PageCount,

        [ValidateSet(
            'Unknown', 'Adults Only 18+', 'Early Childhood', 'Everyone', 'Everyone 10+', 'G',
            'Kids to Adults', 'M', 'MA15+', 'Mature 17+', 'PG', 'R18+', 'Rating Pending', 'Teen', 'X18+'
        )]
        [string] $AgeRating = 'Unknown',
        [string[]] $Tags,
        [uri] $WebURL,
        [string] $MainCharacterOrTeam,
        [string] $ScanInformation,
        [string] $StoryArc,
        [UInt32] $StoryArcNumber,
        [string[]] $SeriesGroup,

        [ValidateScript({ $_.ToString.Split('.')[1].Length -lt 2 })]
        [float] $CommunityRating,
        [string] $Review,
        [string] $GTIN,

        # Creator fields
        [string[]] $Penciller,
        [string[]] $Writer,
        [string[]] $Inker,
        [string[]] $Colorist,
        [string[]] $Editor,
        [string[]] $Letterer,
        [string[]] $CoverArtist,
        [string[]] $Translator,

        [hashtable[]] $PageInfo,

        [ValidateNotNullOrEmpty()]
        [string] $OutputPath = $PWD,
        [ValidateSet('Unknown', 'No', 'Yes', 'YesAndRightToLeft')]
        [string] $Manga = 'Unknown',
        [ValidateSet('cbz')]
        [string] $OutputAs,

        [switch] $BlackAndWhite,
        [switch] $PassThru
    )

    # Validation
    if (-not (Test-Path -PathType Container -Path $ImageFolder)) {
        Write-Error "Image folder path '$ImageFolder' does not exist or is not a directory."
        return
    }

    # Check if the user provided their own filename, otherwise
    # construct one from the title.
    if ($OutputPath.EndsWith('.cbz')) {
        $OutDirectory = $OutputPath | Split-Path -Parent
    } else {
        $OutDirectory = $OutputPath
        $FileName = ($Title -replace " '", '_') + '.cbz'
        $OutputPath = Join-Path $OutputPath $FileName
    }

    # Ensure output directory exists
    if (-not (Test-Path -Path $OutDirectory)) {
        New-Item -Type Directory -Path $OutDirectory | Out-Null
    }

    try {
        $ComicInfoTemplate = [xml] @"
<?xml version="1.0" encoding="utf-8"?>
<ComicInfo xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <Title>$Title</Title>
  <Series>$Series</Series>
  <Number>$VolumeNumber</Number>
  <Count>$VolumesAvailable</Count>
  <Summary>$Summary</Summary>
  <Year>$($ReleaseDate.Year)</Year>
  <Month>$($ReleaseDate.Month)</Month>
  <Day>$($ReleaseDate.Day)</Day>
  <Writer>$($Writer -join ',')</Writer>
  <Penciller>$($Penciller -join ',')</Penciller>
  <Editor>$($Editor -join ',')</Editor>
  <Inker>$($Inker -join ',')</Inker>
  <Colorist>$($Colorist -join ',')</Colorist>
  <Translator>$($Translator -join ',')</Translator>
  <CoverArtist>$($CoverArtist -join ',')</CoverArtist>
  <Letterer>$($Letterer -join ',')</Letterer>
  <Characters>$($Characters -join ',')</Characters>
  <Teams>$($Teams -join ',')</Teams>
  <Locations>$($Locations -join ',')</Locations>
  <Publisher>$Publisher</Publisher>
  <Imprint>$Publisher</Imprint>
  <PageCount>$PageCount</PageCount>
  <IssueNumber>$IssueNumber</IssueNumber>
  <CommunityRating>$CommunityRating</CommunityRating>
  <Review>$Review</Review>
  <GTIN>$GTIN</GTIN>
  <AgeRating>$AgeRating</AgeRating>
  <Genre>$Genre</Genre>
  <LanguageISO>$LanguageISO</LanguageISO>
  <BindingFormat>$BindingFormat</BindingFormat>
  <MainCharacterOrTeam>$MainCharacterOrTeam</MainCharacterOrTeam>
  <ScanInformation>$ScanInformation</ScanInformation>
  <StoryArc>$StoryArc</StoryArc>
  <StoryArcNumber>$StoryArcNumber</StoryArcNumber>
  <SeriesGroup>$SeriesGroup</SeriesGroup>
  <Web>$WebURL</Web>
  <Manga>$(if ($Manga) { 'Yes' } else { 'No' })</Manga>
  <BlackAndWhite>$(if ($BlackAndWhite) { 'Yes' } else { 'No' })</BlackAndWhite>
  <Tags>$($Tags -join ',')</Tags>
  <Notes>Created by New-ComicBook</Notes>
</ComicInfo>
"@

        # Add files node if there are files to include
        if ($PageInfo.Count -gt 0) {
            $PagesNode = $PageInfoTemplate.CreateElement("Pages")

            foreach($Item in $PageInfo) {
                $Item = $PageInfoTemplate.CreateElement("Page")
                $FilesNode.AppendChild($PagesNode) | Out-Null
            }

            $PageInfoTemplate.AppendChild($PagesNode) | Out-Null
        }

        $ComicInfoPath = Join-Path -Path $ImageFolder -ChildPath "ComicInfo.xml"
        if ($PSCmdlet.ShouldProcess($ComicInfoPath, "Create 'ComicInfo' file")) {
            $ComicInfoTemplate.Save($ComicInfoPath)
        }

        switch($OutputAs) {
            'cbz' {
                # Create .cbz (zip) file
                Compress-Archive `
                    -Path "$ImageFolder\*" `
                    -DestinationPath $OutputPath `
                    -Force
                    -PassThru:$PassThru
            }
            default {
                throw "How did you break this?"
            }
        }
    } catch {
        Write-Error "Comic book creation failed with error: $_"
    }
}

function Get-ZipEntry {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $FileName
    )

    if (-not (Test-Path $Path)) {
        Write-Error "Zip file not found: '$Path'"
        return
    }

    $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($ZipFile)
    $ZipEntry = $ZipFile.GetEntry($FileName)

    if (-not $ZipEntry) {
        Write-Warning "File '$FileName' not found in zip"
        return
    }

    try {
        $Stream = $ZipEntry.Open()
        $Reader = [System.IO.StreamReader]::new($Stream)
        $FileContent = $Reader.ReadToEnd()
        return $FileContent
    } catch {
        Write-Error "Failed to read zip '$Path'"
    } finally {
        if ($Reader) { $Reader.Close() }
        if ($Stream) { $Stream.Close() }
    }
}

function Update-ComicBook {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void], [System.IO.FileInfo])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [ValidateNotNullOrEmpty()]
        [string] $Title,

        [ValidateNotNullOrEmpty()]
        [string] $Series,

        [datetime] $ReleaseDate = [datetime]::Today,
        [string] $Publisher,
        [uint32] $IssueNumber,
        [uint32] $VolumeNumber,
        [uint32] $VolumesAvailable,
        [string] $Summary,
        [string] $Genre,
        [string] $LanguageISO = 'en',
        [string] $BindingFormat,
        [string[]] $Characters,
        [string[]] $Teams,
        [string[]] $Locations,
        [uint32] $PageCount,

        [ValidateSet(
            'Unknown', 'Adults Only 18+', 'Early Childhood', 'Everyone', 'Everyone 10+', 'G',
            'Kids to Adults', 'M', 'MA15+', 'Mature 17+', 'PG', 'R18+', 'Rating Pending', 'Teen', 'X18+'
        )]
        [string] $AgeRating = 'Unknown',
        [string[]] $Tags,
        [uri] $WebURL,
        [string] $MainCharacterOrTeam,
        [string] $ScanInformation,
        [string] $StoryArc,
        [UInt32] $StoryArcNumber,
        [string[]] $SeriesGroup,

        [ValidateScript({ $_.ToString.Split('.')[1].Length -lt 2 })]
        [float] $CommunityRating,
        [string] $Review,
        [string] $GTIN,

        # Creator fields
        [string[]] $Penciller,
        [string[]] $Writer,
        [string[]] $Inker,
        [string[]] $Colorist,
        [string[]] $Editor,
        [string[]] $Letterer,
        [string[]] $CoverArtist,
        [string[]] $Translator,

        [hashtable[]] $PageInfo,

        [ValidateSet('Unknown', 'No', 'Yes', 'YesAndRightToLeft')]
        [string] $Manga = 'Unknown',

        [switch] $BlackAndWhite,
        [switch] $PassThru
    )

    [xml] $Metadata = Get-ZipEntry -Path $Path -FileName ComicInfo.Xml

    try {
        foreach ($Param in $PSBoundParameters.GetEnumerator()) {
            $Metadata
        }

        if ($PSCmdlet.ShouldProcess($Path, "Update comic book")) {
            $TempFile = New-TemporaryFile
            $Metadata.Save($TempFile)
            Compress-Archive -Path $Temp
        }
    } catch {
        Write-Error "Failed to update comic book with error: $_"
    }
}


function Open-ComicBook {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo] $Path
    )

    if (-not (Test-Path $Path)) {
        Write-Error "File not found: '$Path'"
        return
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # $NextButton = [System.Windows.Forms.Button] @{
    #     Location = [System.Drawing.Point]
    # }

    #Get-ZipEntry $Path

    try {
        $PictureBox = [System.Windows.Forms.PictureBox] @{
            SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
            Dock = [System.Windows.Forms.DockStyle]::Fill
        }
        $PictureBox.Add_KeyDown({
            if ($_.KeyCode -eq 'Left') { Write-Host 'Left' }
            if ($_.KeyCode -eq 'Right') { Write-Host 'Right' }
        })

        try {
            # Should keep a buffer of images to make revisiting easier.
            $PictureBox.Image = [System.Drawing.Image]::FromFile($Path)
        } catch {
            Write-Error "Failed to load image '$Path'"
        }

        $BackButton = [System.Windows.Forms.Button] @{
            Text = 'Back'
        }
        $BackButton.Add_Click({
            Write-host 'Back'
        })
        $ForwardButton = [System.Windows.Forms.Button] @{
            Text = 'Forward'
        }
        $ForwardButton.Add_Click({
            Write-Host 'Forward'
        })

        $ButtonBox = [System.Windows.Forms.GroupBox]::new()
        $ButtonBox.Controls.AddRange(@($BackButton, $ForwardButton))

        $TableLayoutPanel = [System.Windows.Forms.TableLayoutPanel] @{
            Dock = [System.Windows.Forms.DockStyle]::Fill
            ColumnCount = 1
            #GrowStyle = 'AddRows'
        }
        $TableLayoutPanel.Controls.Add($PictureBox)
        $TableLayoutPanel.Controls.Add($ButtonBox)
        # $TableLayoutPanel.RowStyles.Clear()
        # $TableLayoutPanel.RowStyles.Add(
        #     [System.Windows.Forms.RowStyle] @{
        #         SizeType = [System.Windows.Forms.SizeType]::AutoSize
        #     }
        # )
        # $TableLayoutPanel.RowStyles.Add(
        #     [System.Windows.Forms.RowStyle] @{
        #         SizeType = [System.Windows.Forms.SizeType]::AutoSize
        #     }
        # )

        $Form = [System.Windows.Forms.Form] @{
            Text = "Comic Book Reader"
            TopMost = $True
            StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
        }
        $Form.Controls.Add($TableLayoutPanel)
        #$Form.Controls.Add($PictureBox)
        #$Form.Controls.Add($ButtonBox)

        $Form.ShowDialog()
    } finally {
        # Cleanup
    }
}
