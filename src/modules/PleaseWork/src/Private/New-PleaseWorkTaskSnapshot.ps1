using namespace System.Collections.Generic

<#
.SYNOPSIS
    Loads a TaskFile and captures its state for isolated task execution.

.DESCRIPTION
    Executes TaskFile setup once in a disposable runspace, then returns
    reconstructable PowerShell data, task definitions, command definitions,
    aliases, and file-backed modules. Arbitrary caller state is not captured.

.PARAMETER Path
    Path to the TaskFile to load.

.EXAMPLE
    New-PleaseWorkTaskSnapshot -Path ./TaskFile.ps1

    Loads TaskFile setup and returns a Task Snapshot.

.NOTES
    Examples run in the PleaseWork module's scope.
#>
function New-PleaseWorkTaskSnapshot {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $ResolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $ModulePath = $MyInvocation.MyCommand.Module.Path
    $DefinitionScript = {
        param (
            [string] $ImportedModulePath,
            [string] $TaskFilePath
        )

        $PleaseWorkModule = Import-Module `
            -Name $ImportedModulePath `
            -Force `
            -PassThru `
            -ErrorAction Stop
        $Declarations = @(
            & $PleaseWorkModule {
                param ($Path)

                Get-TaskFileDeclaration -Path $Path
            } $TaskFilePath
        )
        if ($Declarations.Count -eq 0) {
            throw "TaskFile '$TaskFilePath' does not declare any tasks."
        }

        $DeclarationNames = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )

        foreach ($Declaration in $Declarations) {
            if (-not $DeclarationNames.Add($Declaration.Name)) {
                throw "Task '$($Declaration.Name)' is declared more than once."
            }
        }

        $script:PleaseWorkSnapshotDeclarations = @{}
        $script:PleaseWorkSnapshotTasks = `
            [System.Collections.Generic.List[hashtable]]::new()
        $TaskCommand = {
            [CmdletBinding()]
            param (
                [Parameter(ValueFromRemainingArguments)]
                [object[]] $Arguments
            )

            $Declaration = $script:PleaseWorkSnapshotDeclarations[$MyInvocation.MyCommand.Name]
            $script:PleaseWorkSnapshotTasks.Add(@{
                Name = $Declaration.Name
                Description = $Declaration.Description
                Help = $Declaration.Help
                Dependencies = $Declaration.Dependencies
                PathSpecs = $Declaration.PathSpecs
                ScriptBlock = $Arguments[-1]
            })
        }

        foreach ($Declaration in $Declarations) {
            $script:PleaseWorkSnapshotDeclarations[$Declaration.CommandToken] = $Declaration
            Set-Item `
                -LiteralPath "Function:$($Declaration.CommandToken)" `
                -Value $TaskCommand
        }

        $BaselineFunctions = @{}
        foreach ($Function in Get-ChildItem -LiteralPath 'Function:') {
            $BaselineFunctions[$Function.Name] = [string] $Function.ScriptBlock
        }
        $BaselineAliases = @{}
        foreach ($Alias in Get-ChildItem -LiteralPath 'Alias:') {
            $BaselineAliases[$Alias.Name] = $Alias.Definition
        }
        $BaselineModules = @(
            Get-Module |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_.Path) } |
                ForEach-Object { $_.Path }
        )
        $BaselineModuleReferences = @(Get-Module)
        $BaselineVariables = @{}
        foreach ($Variable in Get-Variable -Scope Script) {
            $BaselineVariables[$Variable.Name] = $Variable.Value
        }

        $ErrorActionPreference = 'Stop'
        $null = @(. $TaskFilePath)

        $UnsupportedModules = @(
            Get-Module |
                Where-Object {
                    if (-not [string]::IsNullOrWhiteSpace($_.Path) -and
                        (Test-Path -LiteralPath $_.Path -PathType Leaf)
                    ) {
                        return $false
                    }

                    $CurrentModule = $_
                    -not @(
                        $BaselineModuleReferences |
                            Where-Object {
                                [object]::ReferenceEquals($_, $CurrentModule)
                            }
                    )
                }
        )
        if ($UnsupportedModules.Count -gt 0) {
            $UnsupportedModuleNames = $UnsupportedModules.Name -join ', '
            throw (
                'Task Snapshot cannot capture dynamic modules without a file source: ' +
                $UnsupportedModuleNames
            )
        }

        $ExcludedVariableNames = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )
        $ExcludedVariableNames.UnionWith([string[]] @(
            'PleaseWorkModule',
            'ImportedModulePath',
            'TaskFilePath',
            'Declarations',
            'TaskCommand',
            'Declaration',
            'BaselineFunctions',
            'BaselineAliases',
            'BaselineModules',
            'BaselineModuleReferences',
            'BaselineVariables',
            'Variable',
            'PleaseWorkSnapshotDeclarations',
            'PleaseWorkSnapshotTasks',
            'Function',
            'Alias',
            'ExcludedVariableNames',
            'SnapshotVariables',
            'SnapshotFunctions',
            'SnapshotAliases',
            'SnapshotModules',
            'SnapshotTasks',
            'ConfigVariable',
            'ErrorActionPreference',
            'PSBoundParameters',
            'PSCmdlet',
            'PSScriptRoot',
            'MyInvocation',
            'args',
            'input'
        ))

        $SnapshotVariables = @(
            Get-Variable -Scope Script |
                Where-Object {
                    if ($ExcludedVariableNames.Contains($_.Name)) {
                        return $false
                    }
                    if (-not $BaselineVariables.ContainsKey($_.Name)) {
                        return $true
                    }

                    $BaselineValue = $BaselineVariables[$_.Name]
                    -not ([object]::ReferenceEquals($BaselineValue, $_.Value) -or
                        [object]::Equals($BaselineValue, $_.Value))
                } |
                ForEach-Object {
                    [pscustomobject] @{
                        Name = $_.Name
                        Value = $_.Value
                    }
                }
        )
        $SnapshotFunctions = @(
            Get-ChildItem -LiteralPath 'Function:' |
                Where-Object {
                    $null -eq $_.Module -and
                    (
                        -not $BaselineFunctions.ContainsKey($_.Name) -or
                        $BaselineFunctions[$_.Name] -ne [string] $_.ScriptBlock
                    )
                } |
                ForEach-Object {
                    [pscustomobject] @{
                        Name = $_.Name
                        Definition = [string] $_.ScriptBlock
                        Options = $_.Options
                    }
                } |
                Where-Object {
                    -not $script:PleaseWorkSnapshotDeclarations.ContainsKey($_.Name)
                }
        )
        $SnapshotAliases = @(
            Get-ChildItem -LiteralPath 'Alias:' |
                Where-Object {
                    [string]::IsNullOrWhiteSpace($_.Source) -and
                    (
                        -not $BaselineAliases.ContainsKey($_.Name) -or
                        $BaselineAliases[$_.Name] -ne $_.Definition
                    )
                } |
                ForEach-Object {
                    [pscustomobject] @{
                        Name = $_.Name
                        Definition = $_.Definition
                        Options = $_.Options
                    }
                }
        )
        $SnapshotModules = @(
            Get-Module |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_.Path) -and
                    $_.Path -notin $BaselineModules -and
                    $_.Path -ne $ImportedModulePath
                } |
                ForEach-Object {
                    [pscustomobject] @{
                        Name = $_.Name
                        Path = $_.Path
                    }
                }
        )
        $SnapshotTasks = @(
            $script:PleaseWorkSnapshotTasks |
                ForEach-Object {
                    [pscustomobject] @{
                        Name = $_.Name
                        Description = $_.Description
                        Help = $_.Help
                        Dependencies = $_.Dependencies
                        PathSpecs = $_.PathSpecs
                        ScriptBlockText = [string] $_.ScriptBlock
                    }
                }
        )

        $ConfigVariable = Get-Variable `
            -Name PleaseConfig `
            -Scope Script `
            -ErrorAction SilentlyContinue
        $SnapshotConfig = if ($null -eq $ConfigVariable) {
            @{}
        } elseif ($ConfigVariable.Value -is [System.Collections.IDictionary]) {
            $ConfigVariable.Value
        } else {
            throw '$PleaseConfig must be a dictionary.'
        }

        [pscustomobject] @{
            TaskFilePath = $TaskFilePath
            RunnerModulePath = $ImportedModulePath
            Config = $SnapshotConfig
            Variables = $SnapshotVariables
            Functions = $SnapshotFunctions
            Aliases = $SnapshotAliases
            Modules = $SnapshotModules
            Tasks = $SnapshotTasks
        }
    }

    $Runspace = $null
    $PowerShell = $null
    $OriginalPSModulePath = $env:PSModulePath
    try {
        $Runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        try {
            $Runspace.Open()
        } finally {
            $env:PSModulePath = $OriginalPSModulePath
        }
        $PowerShell = [powershell]::Create()
        $PowerShell.Runspace = $Runspace
        $null = $PowerShell.AddScript($DefinitionScript.ToString())
        $null = $PowerShell.AddParameters(@{
            ImportedModulePath = $ModulePath
            TaskFilePath = $ResolvedPath
        })

        try {
            $Output = @($PowerShell.Invoke())
        } catch {
            $InvocationError = $_
        }

        if ($PowerShell.InvocationStateInfo.State -eq 'Failed') {
            if ($null -eq $InvocationError) {
                $InvocationError = @($PowerShell.Streams.Error) |
                    Select-Object -Last 1
            }

            if ($null -eq $InvocationError) {
                $InvocationError = $PowerShell.InvocationStateInfo.Reason
            }
        }

        if ($null -ne $InvocationError) {
            $ResolvedError = $InvocationError
            for ($Depth = 0; $Depth -lt 8; $Depth++) {
                $InnerError = $null
                if ($ResolvedError -is [System.Management.Automation.ErrorRecord]) {
                    $InnerError = $ResolvedError.Exception
                } elseif ($null -ne $ResolvedError.InnerException) {
                    $InnerError = $ResolvedError.InnerException
                } elseif (
                    $null -ne $ResolvedError.PSObject.Properties['ErrorRecord'].Value
                ) {
                    $InnerError = $ResolvedError.PSObject.Properties['ErrorRecord'].Value
                }

                if ($null -eq $InnerError -or
                    [object]::ReferenceEquals($InnerError, $ResolvedError)
                ) {
                    break
                }
                $ResolvedError = $InnerError
            }
            throw $ResolvedError
        }

        if ($Output.Count -ne 1) {
            throw "TaskFile snapshot produced $($Output.Count) result objects."
        }

        $RawSnapshot = $Output[0]
        $Variables = @(
            foreach ($Variable in $RawSnapshot.Variables) {
                $VariableValue = Copy-PleaseWorkSnapshotValue `
                    -InputObject $Variable.Value `
                    -Name $Variable.Name
                [pscustomobject] @{
                    Name = [string] $Variable.Name
                    Value = $VariableValue
                }
            }
        )
        $SnapshotConfig = Copy-PleaseWorkSnapshotValue `
            -InputObject $RawSnapshot.Config `
            -Name PleaseConfig
        $Snapshot = [pscustomobject] @{
            TaskFilePath = $ResolvedPath
            RunnerModulePath = $RawSnapshot.RunnerModulePath
            Config = $SnapshotConfig
            Variables = $Variables
            Functions = @($RawSnapshot.Functions)
            Aliases = @($RawSnapshot.Aliases)
            Modules = @($RawSnapshot.Modules)
            Tasks = @($RawSnapshot.Tasks)
        }
        Write-Output -NoEnumerate $Snapshot
    } finally {
        if ($null -ne $PowerShell) { $PowerShell.Dispose() }
        if ($null -ne $Runspace) { $Runspace.Dispose() }
    }
}
