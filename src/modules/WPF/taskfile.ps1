$PleaseConfig = @{
    BaseRef = 'origin/main'
}

test: {
    & "$GitRoot/tools/Invoke-Test.ps1" -Suite WPF
}

lint: {
    param([switch] $All)

    if ($All) {
        Start-Nitpicking
    } else {
        git diff --name-only --diff-filter=d --relative $TaskFileRoot | Start-Nitpicking
    }
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

