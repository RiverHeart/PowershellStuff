@{
    RootModule = 'Nitpick.ScriptAnalyzer.psm1'
    ModuleVersion = '0.0.1'
    CompatiblePSEditions = @('Core', 'Desktop')
    GUID = '3fcdebc6-ed2e-4d22-9852-7f3e7bc7a6a4'
    Author = 'Riverheart'
    Copyright = '2026'
    Description = 'PSScriptAnalyzer adapter for built-in Nitpick rules.'
    PowerShellVersion = '5.1'
    RequiredModules = @(
        'Nitpick'
        'PSScriptAnalyzer'
    )
    FunctionsToExport = '*'
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
