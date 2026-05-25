function New-Project {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Name,

        [string] $Author = 'Your Name',
        [string] $Description = 'A new PowerShell project.',
        [string] $PackageProvider = 'NuGet',

        [string] $Path = (Get-Location).Path
    )

    $ProjectPath = Join-Path -Path $Path -ChildPath $Name
    if (Test-Path -Path $ProjectPath) {
        throw "A file or directory already exists at path '$ProjectPath'. Please choose a different name or path."
    }

    New-Item -ItemType Directory -Path $ProjectPath | Out-Null

    # Create project manifest
    $ProjectManifest = @{
        Name = $Name
        Version = '0.1.0'
        Author = $Author
        Description = $Description
        PackageProvider = $PackageProvider
        DevDependencies = @{}
    }

    Export-PowershellDataFile $ProjectManifest -Path (Join-Path -Path $Path -ChildPath "$Name.psd1")
}
