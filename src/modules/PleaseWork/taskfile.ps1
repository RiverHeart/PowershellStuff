$PleaseConfig = @{
    BaseRef = 'origin/main'
}

build: changed('./Public', './Private') {
    Write-Host "Building the project..."

    & "$GitRoot/tools/Build-PSResource.ps1" `
        -ProjectPath ./project.psd1 `
        -DestinationPath "$GitRoot/artifacts/packages"
}
