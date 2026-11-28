@{
    RootModule = 'ModuleDevKit.psm1'
    ModuleVersion = '0.1.0'
    CompatiblePSEditions = @('Desktop', 'Core')
    GUID = 'e73ed904-8b47-45a3-9ed5-3d602c7e720b'
    Author = 'Riverheart'
    CompanyName = 'Unknown'
    Copyright = '(c) Riverheart. All rights reserved.'
    Description = 'A PowerShell module for building, packaging, and managing projects.'
    PowerShellVersion = '5.1'
    RequiredModules = @(
        @{ ModuleName = 'Nitpick'; ModuleVersion = '0.0.1' }
        @{ ModuleName = 'Pester'; ModuleVersion = '5.7.1' }
        @{ ModuleName = 'PleaseWork'; ModuleVersion = '0.1.0' }
    )
    FunctionsToExport = @(
        # Testing
        'Invoke-MDKNewCodeGate'
        'Invoke-MDKTest'
        'Invoke-MDKTestCoverage'

        # General
        'Invoke-MDKModuleBuild'
        'Compress-MDKModule'
        'Get-GitIgnoreFile'
        'Get-GitRepositoryRoot'
        'New-MDKProject'
        'Test-GitIgnoredPath'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @(
        'Build-MDKModule'
    )
    FileList = @(
        'ModuleDevKit.psd1'
        'ModuleDevKit.psm1'
        'README.md'

        # Data/Templates
        'src/Data/Templates/example.psm1'
        'src/Data/Templates/pester.json'
        'src/Data/Templates/project.psd1'
        'src/Data/Templates/taskfile.ps1'

        # Private
        'src/Private/Initialize-UserModulePath.ps1'
        'src/Private/New-Directory.ps1'
        'src/Private/Normalize-RelativePath.ps1'
        'src/Private/Read-JsonFile.ps1'
        'src/Private/Should-Continue.ps1'
        'src/Private/Test-IsExcludedPath.ps1'
        'src/Private/Test-IsInteractive.ps1'

        # Private/Testing
        'src/Private/Testing/Invoke-MDKNewCodeGate/Get-CoverageMap.ps1'
        'src/Private/Testing/Invoke-MDKNewCodeGate/Get-NewCodeMap.ps1'
        'src/Private/Testing/Invoke-MDKNewCodeGate/Resolve-CoverageKey.ps1'
        'src/Private/Testing/Invoke-MDKTest/Get-MDKTestTargets.ps1'
        'src/Private/Testing/Invoke-MDKTest/Test-MDKTestSuiteCollection.ps1'
        'src/Private/Testing/Invoke-MDKTest/Test-RootManifest.ps1'
        'src/Private/Testing/Invoke-MDKTest/Test-SuiteManifest.ps1'
        'src/Private/Testing/Invoke-MDKTestCoverage/Resolve-CoverageOutputPath.ps1'
        'src/Private/Testing/Invoke-MDKTestCoverage/Resolve-EffectiveCoverageMode.ps1'

        # Public
        'src/Public/Build-MDKModule.ps1'
        'src/Public/Compress-MDKModule.ps1'
        'src/Public/Get-GitIgnoreFile.ps1'
        'src/Public/Get-GitRepositoryRoot.ps1'
        'src/Public/Get-RepositoryRoot.ps1'
        'src/Public/New-MDKProject.ps1'
        'src/Public/Test-GitIgnoredPath.ps1'

        # Public/Testing
        'src/Public/Testing/Invoke-MDKNewCodeGate.ps1'
        'src/Public/Testing/Invoke-MDKTest.ps1'
        'src/Public/Testing/Invoke-MDKTestCoverage.ps1'
    )
    PrivateData = @{
        PSData = @{
            Tags = @('ModuleDevelopment', 'Packaging', 'ProjectManagement')
            LicenseUri = 'https://github.com/RiverHeart/PowershellStuff/blob/main/LICENSE'
            ProjectUri = 'https://github.com/RiverHeart/PowershellStuff/tree/main/src/modules/ModuleDevKit'
        }
    }
}
