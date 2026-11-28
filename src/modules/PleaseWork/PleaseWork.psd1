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
        'Complete-PleaseWorkTask'
        'Invoke-PleaseWork'
        'Invoke-PleaseWorkNativeCommand'
        'Resolve-TaskFilePath'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @(
        'exec'
        'pw'
        'please'
    )
    FileList = @(
        'PleaseWork.psd1'
        'PleaseWork.psm1'
        'README.md'
        'src/Classes/DirectedAcyclicGraph.ps1'
        'src/Private/Copy-PleaseWorkSnapshotValue.ps1'
        'src/Private/Format-PleaseWorkTaskHelp.ps1'
        'src/Private/Get-GitChangedPath.ps1'
        'src/Private/Get-GitChangeset.ps1'
        'src/Private/Get-PleaseWorkTaskHelp.ps1'
        'src/Private/Get-TaskDeclaration.ps1'
        'src/Private/Get-TaskDescription.ps1'
        'src/Private/Get-TaskFileDeclaration.ps1'
        'src/Private/Invoke-PleaseWorkTask.ps1'
        'src/Private/New-PleaseWorkInitialSessionState.ps1'
        'src/Private/New-PleaseWorkPreparedTaskSet.ps1'
        'src/Private/New-PleaseWorkSnapshotTaskSet.ps1'
        'src/Private/New-PleaseWorkTaskContext.ps1'
        'src/Private/New-PleaseWorkTaskExecutor.ps1'
        'src/Private/New-PleaseWorkTaskSnapshot.ps1'
        'src/Private/Resolve-ParamBlock.ps1'
        'src/Private/Resolve-TaskOrder.ps1'
        'src/Private/Should-Process.ps1'
        'src/Private/Write-PleaseWorkTaskExecutorStream.ps1'
        'src/Public/Complete-PleaseWorkTask.ps1'
        'src/Public/Invoke-PleaseWork.ps1'
        'src/Public/Invoke-PleaseWorkNativeCommand.ps1'
        'src/Public/Resolve-TaskFilePath.ps1'
    )
    PrivateData = @{
        PSData = @{
            Tags = @('TaskRunner')
            LicenseUri = 'https://github.com/RiverHeart/PowershellStuff/blob/main/LICENSE'
            ProjectUri = 'https://github.com/RiverHeart/PowershellStuff/tree/main/src/modules/PleaseWork'
        }
    }
}
