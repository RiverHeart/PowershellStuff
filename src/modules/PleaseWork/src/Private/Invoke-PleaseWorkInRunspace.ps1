<#
.SYNOPSIS
    Invokes PleaseWork in a dedicated runspace.
#>
function Invoke-PleaseWorkInRunspace {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ModulePath,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $InvocationParameters,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $WorkingDirectory
    )

    $Runspace = $null
    $PowerShell = $null
    try {
        $InvocationScript = {
            param ($ImportedModulePath, $Parameters)

            $PleaseWorkModule = Import-Module `
                -Name $ImportedModulePath `
                -Force `
                -PassThru `
                -ErrorAction Stop

            # Parse declaration metadata before loading the TaskFile so the temporary DSL commands
            # can register each body without duplicating dependency and help parsing at runtime.
            $TaskFilePath = $Parameters.TaskFile
            $Declarations = @(
                & $PleaseWorkModule {
                    param ($Path)

                    Get-TaskFileDeclaration -Path $Path
                } $TaskFilePath
            )

            if ($Declarations.Count -eq 0) {
                throw "TaskFile '$TaskFilePath' does not declare any tasks."
            }

            $script:PleaseWorkRunspaceDeclarations = @{}
            $script:PleaseWorkRunspaceTasks = [System.Collections.Generic.List[hashtable]]::new()

            # Create the invocation wrapper in the same script scope as the TaskFile. Context
            # variables injected here are therefore visible to its unbound task scriptblocks.
            $RunspaceTaskInvoker = {
                param ($TaskScriptBlock, $TaskContext, $TaskArguments)

                $ErrorActionPreference = 'Stop'
                foreach ($VariableName in $TaskContext.Keys) {
                    if ($VariableName -eq 'ErrorActionPreference') {
                        continue
                    }
                    Set-Variable `
                        -Name ([string] $VariableName) `
                        -Value $TaskContext[$VariableName] `
                        -Scope Local
                }

                if ($TaskArguments -is [System.Collections.IDictionary]) {
                    & $TaskScriptBlock @TaskArguments
                } elseif ($null -ne $TaskArguments) {
                    [object[]] $PositionalArguments = @($TaskArguments)
                    & $TaskScriptBlock @PositionalArguments
                } else {
                    & $TaskScriptBlock
                }
            }

            # Every declaration token (for example, build:) points to this registrar. Looking up
            # metadata by command name avoids creating one closure per task declaration.
            $TaskCommand = {
                [CmdletBinding()]
                param (
                    [Parameter(ValueFromRemainingArguments)]
                    [object[]] $Arguments
                )

                $Declaration = $script:PleaseWorkRunspaceDeclarations[$MyInvocation.MyCommand.Name]
                $script:PleaseWorkRunspaceTasks.Add(@{
                    Name = $Declaration.Name
                    Description = $Declaration.Description
                    Help = $Declaration.Help
                    Dependencies = $Declaration.Dependencies
                    PathSpecs = $Declaration.PathSpecs
                    ScriptBlock = $Arguments[-1]
                })
            }

            foreach ($Declaration in $Declarations) {
                $script:PleaseWorkRunspaceDeclarations[$Declaration.CommandToken] = $Declaration
                Set-Item `
                    -LiteralPath "Function:global:$($Declaration.CommandToken)" `
                    -Value $TaskCommand
            }

            # Dot-sourcing makes the runspace script scope the durable TaskFile scope. Top-level
            # variables and functions remain available, and $script: state persists across tasks.
            $OriginalErrorActionPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Stop'
                $null = @(. $TaskFilePath)
            } finally {
                $ErrorActionPreference = $OriginalErrorActionPreference
            }

            $ConfigVariable = Get-Variable `
                -Name PleaseConfig `
                -Scope Local `
                -ErrorAction SilentlyContinue

            $TaskConfig = if ($null -eq $ConfigVariable) {
                @{}
            } elseif (-not ($ConfigVariable.Value -is [System.Collections.IDictionary])) {
                throw '$PleaseConfig must be a dictionary.'
            } else {
                $ConfigVariable.Value
            }

            # Hand the registered tasks to the imported module so its existing planner can run
            # unchanged while task bodies and their invoker remain owned by this runspace scope.
            & $PleaseWorkModule {
                param ($Tasks, $Config, $Invoker)

                $script:PreparedTaskSet = New-PleaseWorkPreparedTaskSet `
                    -Tasks $Tasks `
                    -Config $Config `
                    -Invoker $Invoker
            } $script:PleaseWorkRunspaceTasks $TaskConfig $RunspaceTaskInvoker

            Invoke-PleaseWork @Parameters
        }

        $PowerShell = New-PleaseWorkTaskExecutor `
            -ScriptBlock $InvocationScript `
            -Parameters @{
                ImportedModulePath = $ModulePath
                Parameters = $InvocationParameters
            } `
            -WorkingDirectory $WorkingDirectory

        $Runspace = $PowerShell.Runspace

        # Collect success output separately so it can be emitted even when the child pipeline
        # terminates and the original failure must be rethrown in the caller.
        $Output = [System.Collections.Generic.List[psobject]]::new()
        $InvocationError = $null
        try {
            $null = $PowerShell.Invoke($null, $Output)
        } catch {
            $InvocationError = $PowerShell.InvocationStateInfo.Reason
            if ($null -eq $InvocationError) {
                $InvocationError = $_.Exception.InnerException
            }
        }

        # Synchronous invocation buffers auxiliary streams until the child pipeline completes.
        Write-PleaseWorkTaskExecutorStream -Executor $PowerShell -Caller $PSCmdlet
        Write-Output -InputObject $Output

        if ($null -ne $InvocationError) {
            throw $InvocationError
        }
        if ($PowerShell.InvocationStateInfo.State -eq 'Failed') {
            throw $PowerShell.InvocationStateInfo.Reason
        }
    } finally {
        if ($null -ne $PowerShell) { $PowerShell.Dispose() }
        if ($null -ne $Runspace) { $Runspace.Dispose() }
    }
}
