$PleaseConfig = @{
    BaseRef = 'origin/main'
}

build: changed('./src', './project.psd1') {
    & "$GitRoot/tools/Build-PSResource.ps1" `
        -ProjectPath ./project.psd1 `
        -DestinationPath "$GitRoot/artifacts/packages"
}

lint: changed('./**/*.ps1') {
    Invoke-ScriptAnalyzer -Path . -Settings "$GitRoot/PSScriptAnalyzerSettings.psd1"
}

test: changed('./src', './Tests') {
    & "$GitRoot/tools/Invoke-Test.ps1" -TestSuite PleaseWork
}
