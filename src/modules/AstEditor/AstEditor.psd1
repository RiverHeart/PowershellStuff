@{
    RootModule = 'AstEditor.psm1'
    ModuleVersion = '0.1.0'
    CompatiblePSEditions = @('Desktop', 'Core')
    GUID = '1304ca52-da99-4255-b393-608a5fdb2e85'
    Author = 'Riverheart'
    CompanyName = 'Unknown'
    Copyright = '(c) 2026 Riverheart. All rights reserved.'
    Description = 'Edits PowerShell source using immutable ASTs and validated text overlays.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Add-WpfDslLoadedHandler'
        'Edit-PSFunction'
        'Extract-AstFunction'
        'Find-AstNode'
        'New-AstDocument'
        'Resolve-AstDocument'
        'Save-AstDocument'
        'Set-AstFunction'
        'Show-AstDiff'
        'Split-PSFunction'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('AST', 'Editor', 'PowerShell')
        }
    }
}
