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
        # PowerShellData
        'ConvertFrom-PowerShellData'

        # Formatting
        'Format-AstText'
        'Format-AstTree'

        # General
        'Add-AstTextEdit'
        'Add-WpfDslLoadedHandler'
        'Edit-PSFunction'
        'Expand-AstTokenTree'
        'Find-AstNode'
        'Find-AstScriptExtent'
        'Find-AstToken'
        'Get-AstChildren'
        'Get-AstExtractedFunction'
        'New-AstDocument'
        'New-AstCollectionEdit'
        'New-AstScriptExtent'
        'New-AstTextEdit'
        'Resolve-AstDocument'
        'Save-AstDocument'
        'Set-AstFunction'
        'Show-AstDiff'
        'Split-PSFunction'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = '*'
    FileList = @(
        'AstEditor.psm1'
        'Languages/en-US/AstEditor.psd1'

        # Private/AstDiffing
        'Private/AstDiffing/Add-AstDiffContext.ps1'
        'Private/AstDiffing/Add-AstDiffLine.ps1'
        'Private/AstDiffing/Format-AstDiff.ps1'
        'Private/AstDiffing/Get-AstDiffHunk.ps1'
        'Private/AstDiffing/Get-AstLineIndexFromOffset.ps1'

        # Private
        'Private/Get-AstFileSnapshot.ps1'
        'Private/Get-AstSourceFingerprint.ps1'
        'Private/Get-AstTextLine.ps1'
        'Private/Get-LocalizedString.ps1'
        'Private/Get-ScriptBlockStatementText.ps1'
        'Private/Invoke-AstFileReplacement.ps1'
        'Private/Invoke-AstFunctionRewritePlan.ps1'
        'Private/New-AstFunctionRewritePlan.ps1'
        'Private/Should-Process.ps1'
        'Private/Test-ScriptBlockStatementTextEquivalent.ps1'

        # Public/Formatting
        'Public/Formatting/Format-AstText.ps1'
        'Public/Formatting/Format-AstTree.ps1'

        # Public/PowerShellData
        'Public/PowerShellData/ConvertFrom-PowerShellData.ps1'

        # Public/StructuredFileEditing
        'Public/StructuredFileEditing/Edit-PSFunction.ps1'
        'Public/StructuredFileEditing/Extract-AstFunction.ps1'
        'Public/StructuredFileEditing/Split-PSFunction.ps1'

        # Public
        'Public/Add-AstTextEdit.ps1'
        'Public/Find-AstNode.ps1'
        'Public/Find-AstScriptExtent.ps1'
        'Public/New-AstCollectionEdit.ps1'
        'Public/New-AstDocument.ps1'
        'Public/New-AstScriptExtent.ps1'
        'Public/New-AstTextEdit.ps1'
        'Public/Resolve-AstDocument.ps1'
        'Public/Save-AstDocument.ps1'
        'Public/Set-AstFunction.ps1'
        'Public/Show-AstDiff.ps1'
    )
    PrivateData = @{
        PSData = @{
            LicenseUri = 'https://github.com/RiverHeart/PowershellStuff/blob/main/LICENSE'
            ProjectUri = 'https://github.com/RiverHeart/PowershellStuff/tree/main/src/modules/AstEditor'
            Tags = @('AST', 'PowerShell')
        }
    }
}
