# Runs Pester tests
test: {
    param(
        [string] $Project,
        [string] $TestSuite,
        [string[]] $Path
    )

    Invoke-MDKTest @PSBoundParameters
}

# Runs the Nitpick linter against changed files or all when `-All` is given.
lint: {
    param([switch] $All)

    if ($All) {
        Start-Nitpicking
    } else {
        git diff --name-only --diff-filter=d --relative $TaskFileRoot | Start-Nitpicking
    }
}

# Cleans the build artifact directory
clean: {
    if ([string]::IsNullOrEmpty($TaskFileRoot)) {
        throw 'The $TaskFileRoot variable is not set.'
    }
    if (-not (Test-Path -LiteralPath $TaskFileRoot -PathType Container)) {
        return
    }
    Remove-Item -Path "$TaskFileRoot/artifacts" -Recurse -Force -ErrorAction SilentlyContinue
}

# Builds the module as a nuget package
build: clean {
    Build-MDKModule -ProjectPath $TaskFileRoot
}

# Publishes the module to the PowerShell Gallery
publish: {
    $ModuleName = Split-Path -Path $TaskFileRoot -Leaf
    $Manifest = Import-PowerShellDataFile -LiteralPath "$TaskFileRoot/$ModuleName.psd1" -ErrorAction Stop
    $Version = $Manifest.ModuleVersion
    if ([string]::IsNullOrWhiteSpace($env:PSGalleryApiKey)) {
        throw 'The PSGalleryApiKey environment variable is required to publish.'
    }
    Publish-PSResource `
        -NupkgPath "$TaskFileRoot/artifacts/packages/$ModuleName.$Version.nupkg" `
        -Repository 'PSGallery' `
        -ApiKey $env:PSGalleryApiKey `
        -Verbose
}
