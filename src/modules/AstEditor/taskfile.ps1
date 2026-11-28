test: {
    param([string] $Path)

    if ($Path) {
        & "$GitRoot/tools/Invoke-Test.ps1" -Suite AstEditor -Path $Path
    } else {
        & "$GitRoot/tools/Invoke-Test.ps1" -Suite AstEditor
    }
}

lint: {
    param([switch] $All)

    if ($All) {
        Start-Nitpicking
    } else {
        git diff --name-only --diff-filter=d --relative $TaskFileRoot | Start-Nitpicking
    }
}

clean: {
    if ([string]::IsNullOrEmpty($TaskFileRoot)) {
        throw 'The $TaskFileRoot variable is not set.'
    }
    if (-not (Test-Path -LiteralPath $TaskFileRoot -PathType Container)) {
        return
    }
    Remove-Item -Path "$TaskFileRoot/artifacts" -Recurse -Force -ErrorAction SilentlyContinue
}

build: clean {
    Build-MDKModule -ProjectPath $TaskFileRoot
}

publish: {
    $ModuleName = Split-Path -Path $TaskFileRoot -Leaf
    $Manifest = Import-PowerShellDataFile -LiteralPath "$TaskFileRoot/$ModuleName.psd1" -ErrorAction Stop
    $Version = $Manifest.ModuleVersion
    if ([string]::IsNullOrWhiteSpace($env:PSGalleryApiKey)) {
        throw 'The PSGalleryApiKey environment variable is required to publish.'
    }
    Publish-PSResource `
        -NupkgPath "$TaskFileRoot/artifacts/packages/AstEditor.$Version.nupkg" `
        -Repository 'PSGallery' `
        -ApiKey $env:PSGalleryApiKey `
        -Verbose
}
