$PleaseConfig = @{
    BaseRef = 'origin/main'
}

build: changed('./src', './project.psd1') {
    Write-Host "Building the project..."

    & "$GitRoot/tools/Build-PSResource.ps1" `
        -ProjectPath ./project.psd1 `
        -DestinationPath "$GitRoot/artifacts/packages"
}

lint: changed('./**/*.ps1') {
    Write-Host "Linting the project..."

    Invoke-ScriptAnalyzer -Path . -Settings "$GitRoot/PSScriptAnalyzerSettings.psd1"
}

test: changed('./src', './Tests') {
    Write-Host "Running tests..."

    & "$GitRoot/tools/Invoke-Test.ps1" -TestSuite PleaseWork
}
