$PleaseConfig = @{
    BaseRef = 'origin/main'
}

#.DESCRIPTION
#  Packages the module
build: test changed('./src', './project.psd1') {
    & "$GitRoot/tools/Build-PSResource.ps1" `
        -ProjectPath ./project.psd1 `
        -DestinationPath "$GitRoot/artifacts/packages"
}

#.DESCRIPTION
#    Runs PSScriptAnalyzer
lint: changed('./**/*.ps1') {
    Write-Host "Found $($ChangedFiles.Count) changed files to analyze."
    $Results = $ChangedFiles | Invoke-ScriptAnalyzer -Settings "$GitRoot/PSScriptAnalyzerSettings.psd1"
    if ($Results.Count -gt 0) {
        Write-Host "Found $($Results.Count) issues."
        $Results | Out-Host  # Use Out-Host for immediate output instead of Write-Host to avoid throw discarding buffered output.
        throw "PSScriptAnalyzer found issues."
    } else {
        Write-Host "No issues found."
    }
}

#.DESCRIPTION
#     Runs Pester tests
test: lint changed('./src', './Tests') {
    & "$GitRoot/tools/Invoke-Test.ps1" -TestSuite PleaseWork
}

#.DESCRIPTION
#     Installs dev dependencies
install: {
    if ($null -ne $env:VSCODE_INJECTION) {
        Write-Warning "Skipping install in VSCode injection context."
        return
    }
    $Project = Import-PowerShellDataFile -LiteralPath "$TaskFileRoot/project.psd1"
    $Project.DevDependencies.GetEnumerator() | ForEach-Object {
        $InstallParams = @{
            Name = $_.Key
            Scope = 'CurrentUser'
            Verbose = $true
        }
        if ($_.Value.StartsWith('^')) {
            $InstallParams.MinimumVersion = $_.Value.TrimStart('^')
        } else {
            $InstallParams.RequiredVersion = $_.Value
        }
        Install-Module @InstallParams
    }
}
