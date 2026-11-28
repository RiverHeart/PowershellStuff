using namespace System.IO

<#
.SYNOPSIS
    Creates a NuGet package (.nupkg) for a PowerShell module.

.DESCRIPTION
    Creates a NuGet package (.nupkg) for a PowerShell module.

    Reads the module manifest (.psd1) to gather metadata and
    packages the module files into a .nupkg file with the
    associated boilerplate.

.NOTES
    This is not an exhaustive implementation so it may fail
    in unexpected ways. You're probably better off using the
    native `Compress-PSResource` cmdlet.

    Use at your own peril.

.EXAMPLE
    Compress-MDKModule `
        -Name 'ExampleName' `
        -ModulePath 'path/to/module' `
        -PassThru

.LINK
    https://stackoverflow.com/questions/9642183/how-to-create-a-nuget-package-by-hand-without-nuget-exe-or-nuget-explorer
#>
function Compress-MDKModule {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void], [System.IO.FileInfo])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ModulePath,

        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [ValidateNotNullOrEmpty()]
        [string] $OutputPath,

        [switch] $PassThru
    )

    # Validation
    if (-not (Test-Path -PathType Container -Path $ModulePath)) {
        Write-Error "Module path '$ModulePath' does not exist or is not a directory."
        return
    }

    if ($OutputPath) {
        if (-not (Test-Path -Path $OutputPath)) {
            New-Item -Type Directory -Path $OutputPath | Out-Null
        }
    } else {
        $OutputPath = Get-Location
    }

    if (-not $Name) {
        $Name = (Get-Item -Path $ModulePath).BaseName
    }

    $TempDir = $null

    # Where the work is done
    try {
        # Load module manifest
        $ManifestPath = Join-Path -Path $ModulePath -ChildPath (Get-ChildItem -Path $ModulePath -Filter *.psd1).Name
        $ModuleManifest = Import-PowerShellDataFile -Path $ManifestPath

        $TempDirPath = Join-Path -Path ([Path]::GetTempPath()) -ChildPath (
            "New-ModulePackage_${Name}_$([guid]::NewGuid().ToString('N'))"
        )
        $TempDir = New-Item -Path $TempDirPath -ItemType Directory -ErrorAction Stop

        New-Item -Type Directory -Path (Join-Path -Path $TempDir.FullName -ChildPath 'package/services/metadata/core-properties') | Out-Null
        New-Item -Type Directory -Path (Join-Path -Path $TempDir.FullName -ChildPath '_rels') | Out-Null

        $FileList = if ($ModuleManifest.FileList) {
            @($ModuleManifest.FileList) + @((Get-Item -LiteralPath $ManifestPath).Name) |
                Select-Object -Unique
        } else {
            '**'
        }

        $Owners = if ($ModuleManifest.CompanyName) {
            $ModuleManifest.CompanyName
            $Copyright = "(c) $($ModuleManifest.CompanyName). All rights reserved. $(Get-Date -Format 'yyyy')"
        } elseif ($ModuleManifest.Author) {
            $ModuleManifest.Author
            $Copyright = "(c) $($ModuleManifest.Author). All rights reserved. $(Get-Date -Format 'yyyy')"
        } else {
            'Unknown'
        }

        # Override copyright if specified in manifest
        if ($ModuleManifest.Copyright) {
            $Copyright = $ModuleManifest.Copyright
        }

        $Tags = @('PSModule')
        if ($ModuleManifest.PrivateData.PSData.Tags) {
            $Tags += $ModuleManifest.PrivateData.PSData.Tags
        }

        # Create .nuspec content
        $NuspecTemplate = [xml] @"
<?xml version="1.0"?>
<package xmlns="http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd">
    <metadata>
        <id>$Name</id>
        <version>$($ModuleManifest.ModuleVersion)</version>
        <authors>$($ModuleManifest.Author)</authors>
        <description>$($ModuleManifest.Author)</description>
        <copyright>$Copyright</copyright>
        <releaseNotes>$($ModuleManifest.PrivateData.PSData.ReleaseNotes)</releaseNotes>
        <projectUrl>$($ModuleManifest.PrivateData.PSData.ProjectUri)</projectUrl>
        <licenseUrl>$($ModuleManifest.PrivateData.PSData.LicenseUri)</licenseUrl>
        <tags>$($Tags -join ' ')</tags>
        <owners>$Owners</owners>
    </metadata>
</package>
"@

        # Add files node if there are files to include
        $FilesNode = $NuspecTemplate.CreateElement("files")

        # Add file entries to .nuspec
        foreach($File in $FileList) {
            $FileNode = $NuspecTemplate.CreateElement("file")
            $FileNode.SetAttribute("src", $File)
            $FileNode.SetAttribute("target", "content")
            $FilesNode.AppendChild($FileNode) | Out-Null
        }

        $NuspecTemplate.package.AppendChild($FilesNode) | Out-Null

        $NuspecPath = Join-Path -Path $TempDir.FullName -ChildPath "$Name.nuspec"
        if ($PSCmdlet.ShouldProcess($NuspecPath, "Create 'nuspec' file")) {
            $NuspecTemplate.Save($NuspecPath)
        }

        # Create _rels/.rels content

        $NuspecRelId = "R" + [guid]::NewGuid().ToString().Replace('-','').Substring(0, 15).ToUpper()
        $MetadataRelId = "R" + [guid]::NewGuid().ToString().Replace('-','').Substring(0, 15).ToUpper()
        $RelsTemplate = [xml] @"
<?xml version="1.0" encoding="utf-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Type="http://schemas.microsoft.com/packaging/2010/07/manifest" Target="/$Name.nuspec" Id="$NuspecRelId" />
    <Relationship Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="/package/services/metadata/core-properties/69685b5d96e14f99ad40152411cde3eb.psmdcp" Id="$MetadataRelId" />
</Relationships>
"@

        $RelsPath = Join-Path -Path $TempDir.FullName -ChildPath '_rels/.rels'
        if ($PSCmdlet.ShouldProcess($RelsPath, "Create 'rel' file")) {
            $RelsTemplate.Save($RelsPath)
        }

        # Create package/services/metadata/core-properties/core.psmdcp content

        $MetadataId = [guid]::NewGuid().ToString('N')
        $MetadataTemplate = [xml] @"
<?xml version="1.0" encoding="utf-8"?>
<coreProperties xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.openxmlformats.org/package/2006/metadata/core-properties">
<dc:creator>$($ModuleManifest.Author)</dc:creator>
<dc:description>$($ModuleManifest.Description)</dc:description>
<dc:identifier>$Name</dc:identifier>
<version>$($ModuleManifest.ModuleVersion)</version>
<keywords></keywords>
<lastModifiedBy>New-ModulePackage</lastModifiedBy>
</coreProperties>
"@

        $MetadataPath = Join-Path -Path $TempDir.FullName -ChildPath "package/services/metadata/core-properties/$MetadataId.psmdcp"
        if ($PSCmdlet.ShouldProcess($MetadataPath, "Create 'metadata' file")) {
            $MetadataTemplate.Save($MetadataPath)
        }

        # Create Content_Types.xml content
        $ContentTypesTemplate = [xml] @"
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml" />
    <Default Extension="psmdcp" ContentType="application/vnd.openxmlformats-package.core-properties+xml" />
    <Default Extension="psd1" ContentType="application/octet" />
    <Default Extension="psm1" ContentType="application/octet" />
    <Default Extension="html" ContentType="application/octet" />
    <Default Extension="ps1" ContentType="application/octet" />
    <Default Extension="txt" ContentType="application/octet" />
    <Default Extension="xml" ContentType="application/octet" />
    <Default Extension="nuspec" ContentType="application/octet" />
    <Override PartName="/LICENSE" ContentType="application/octet" />
</Types>
"@

        $ContentTypesPath = Join-Path -Path $TempDir.FullName -ChildPath '[Content_Types].xml'
        if ($PSCmdlet.ShouldProcess($ContentTypesPath, "Create 'ContentTypes' file")) {
            $ContentTypesTemplate.Save($ContentTypesPath)
        }

        # Copy files
        $FilesToCopy = if ($FileList -eq '**') {
            Get-ChildItem -LiteralPath $ModulePath -File -Recurse -Force -ErrorAction Stop
        } else {
            foreach ($File in $FileList) {
                if ([WildcardPattern]::ContainsWildcardCharacters($File)) {
                    throw "Module manifest FileList path '$File' must not contain wildcards."
                }

                Get-Item -LiteralPath (Join-Path -Path $ModulePath -ChildPath $File) `
                    -ErrorAction Stop
            }
        }

        $FilesToCopy | ForEach-Object {
            if ($_.PSIsContainer) {
                throw "Module manifest FileList path '$($_.FullName)' is not a file."
            }

            $RelativePath = $_.FullName.Substring($ModulePath.Length).TrimStart('\','/')
            $DestinationPath = Join-Path -Path $TempDir.FullName -ChildPath $RelativePath
            $DestinationDir = Split-Path -Path $DestinationPath -Parent
            if (-not (Test-Path -Path $DestinationDir)) {
                New-Item -Type Directory -Path $DestinationDir | Out-Null
            }
            Copy-Item -LiteralPath $_.FullName -Destination $DestinationPath
        }

        # Create .nupkg (zip) file. Compress-Archive in Windows PowerShell 5.1
        # does not support PassThru, so return the created file explicitly.
        $PackagePath = Join-Path `
            -Path $OutputPath `
            -ChildPath "$Name.$($ModuleManifest.ModuleVersion).nupkg"

        $ArchivePath = [Path]::ChangeExtension($PackagePath, '.zip')

        Compress-Archive `
            -Path "$($TempDir.FullName)\*" `
            -DestinationPath $ArchivePath `
            -Force `
            -ErrorAction Stop

        Move-Item -LiteralPath $ArchivePath -Destination $PackagePath -Force -ErrorAction Stop

        if ($PassThru) {
            Get-Item -LiteralPath $PackagePath -ErrorAction Stop
        }
    } catch {
        Write-Error "$_"
    } finally {
        # Clean up
        if ($null -ne $TempDir -and (Test-Path -Path $TempDir.FullName)) {
            Remove-Item -Path $TempDir.FullName -Recurse -Force
        }
    }
}
