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
    PrivateData = @{
        PSData = @{}
    }
}
