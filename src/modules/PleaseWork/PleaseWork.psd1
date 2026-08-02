@{
    RootModule = 'PleaseWork.psm1'
    ModuleVersion = '0.1.0'
    CompatiblePSEditions = @('Desktop', 'Core')
    GUID = '423e4976-6ef8-4d7c-b3bd-8313fc801b53'
    Author = 'Riverheart'
    CompanyName = 'Unknown'
    Copyright = '(c) Riverheart. All rights reserved.'
    Description = 'A small PowerShell task runner with makefile-like task declarations.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Invoke-PleaseWork'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @(
        'pw'
        'please'
    )
    PrivateData = @{
        PSData = @{
            Tags = @('TaskRunner', 'Build')
        }
    }
}
