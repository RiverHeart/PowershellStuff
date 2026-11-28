using namespace System.IO

<#
.SYNOPSIS
    Scaffolds a new PowerShell module project with a conventional folder
    structure and starter files.

.DESCRIPTION
    Scaffolds a new PowerShell module project with a conventional folder
    structure and starter files.

.PARAMETER Name
    Name of the project/module.

.PARAMETER Path
    Parent directory where the project folder should be created. Defaults to the current directory.

.PARAMETER Author
    Author of the module.

.PARAMETER Description
    Description of the module.

.PARAMETER ModuleVersion
    Version of the module.

.PARAMETER Bare
    Create a more minimal scaffold with a starter module file and placeholder content,
    without the default folder structure.

.EXAMPLE
    New-MDKProject MyApp

.EXAMPLE
    New-MDKProject MyApp -Path C:\Projects

.EXAMPLE
    New-MDKProject MyApp -Bare
#>
function New-MDKProject {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_.-]*$')]
        [string] $Name,

        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [DirectoryInfo] $Path = $PWD,

        [string] $Author = '',
        [string] $Description = '',
        [version] $ModuleVersion = '1.0.0',

        [switch] $Bare
    )

    $ProjectRoot = Join-Path $Path $Name
    $ProjectFile = Join-Path $ProjectRoot "project.psd1"
    $ProjectFileTemplate = [Path]::Combine($script:ModuleRoot, 'src', 'Data', 'Templates', "project.psd1")
    $Manifest = Join-Path $ProjectRoot "$Name.psd1"
    $ModuleFile = Join-Path $ProjectRoot "$Name.psm1"
    $ModuleFileTemplate = [Path]::Combine($script:ModuleRoot, 'src', 'Data', 'Templates', "example.psm1")
    $TaskFile = Join-Path $ProjectRoot 'Taskfile.ps1'
    $TaskFileTemplate = [Path]::Combine($script:ModuleRoot, 'src', 'Data', 'Templates', "taskfile.ps1")
    $PesterConfig = Join-Path $ProjectRoot 'pester.json'
    $PesterConfigTemplate = [Path]::Combine($script:ModuleRoot, 'src', 'Data', 'Templates', "pester.json")
    $SourceRoot = Join-Path $ProjectRoot 'src'

    if (-not $PSCmdlet.ShouldProcess($ProjectRoot, 'Scaffold PowerShell module')) {
        return
    }

    if (-not (Test-Path $ProjectRoot)) {
        New-Item -Path $ProjectRoot -ItemType Directory -Force | Out-Null
    }

    $IsEmpty = $ProjectRoot | Get-ChildItem -Force | Measure-Object | Select-Object -ExpandProperty Count
    if ($IsEmpty -gt 0) {
        throw "Project root '$ProjectRoot' is not empty."
    }

    New-ModuleManifest `
        -Path $Manifest `
        -ModuleVersion $ModuleVersion `
        -Author $Author `
        -Description $Description `
        -RootModule $ModuleFile `
        -FileList @("$Name.psd1", "$Name.psm1")

    Copy-Item -Path $ModuleFileTemplate -Destination $ModuleFile
    (Get-Content -Raw -Path $ProjectFileTemplate) -replace '__ModuleName__', $Name |
        Out-File -FilePath $ProjectFile -Force

    if (-not $Bare) {
        "# $Name" | Out-File -FilePath (Join-Path $ProjectRoot 'README.md') -Force
        New-Item -Path $SourceRoot -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $SourceRoot 'Classes') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $SourceRoot 'Public') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $SourceRoot 'Private') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $ProjectRoot 'tests') -ItemType Directory -Force | Out-Null
        Copy-Item -Path $TaskFileTemplate -Destination $TaskFile -Force
        Copy-Item -Path $PesterConfigTemplate -Destination $PesterConfig -Force
    }
}
