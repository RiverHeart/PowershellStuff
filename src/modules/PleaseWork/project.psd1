@{
    Name = 'PleaseWork'
    PackageProvider = 'NuGet'
    DevDependencies = @{
        PSScriptAnalyzer = '^1.24.0'
        Pester = '^5.7.1'
    }
    Package = @{
        Include = @(
            'PleaseWork.psd1'
            'PleaseWork.psm1'
            'Private'
            'Public'
            'README.md'
        )
    }
}
