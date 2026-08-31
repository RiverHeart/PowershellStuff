$PleaseConfig = @{
    BaseRef = 'origin/main'
}

# Runs ScriptAnalyzer against changed Powershell files.
lint: changed('./**/*.ps1') {
    # Use exec to run ScriptAnalyzer in a fresh process. This is a workaround
    # to run from Powershell Extension and also prevents `-EnableExit` from
    # terminating the task runner.
    exec powershell Invoke-ScriptAnalyzer -Path $ChangedFiles -EnableExit -Settings "$GitRoot/PSScriptAnalyzerSettings.psd1"
}

# Runs ScriptAnalyzer against all Powershell files.
lint-full: {
    # Use exec to run ScriptAnalyzer in a fresh process. This is a workaround
    # to run from Powershell Extension and also prevents `-EnableExit` from
    # terminating the task runner.
    exec powershell Invoke-ScriptAnalyzer -Path './src/**/*.ps1' -EnableExit -Settings "$GitRoot/PSScriptAnalyzerSettings.psd1"
}

# Runs Pester tests against changed Powershell files.
test: lint changed('./**/*.ps1') {
    & "$GitRoot/tools/Invoke-Test.ps1" -TestSuite WPF
}

# Runs Pester tests against all Powershell files.
test-full: lint-full {
    & "$GitRoot/tools/Invoke-Test.ps1" -TestSuite WPF
}

# Installs dev dependencies
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

