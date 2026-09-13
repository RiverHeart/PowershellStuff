<#
.SYNOPSIS
    Invokes a native command and fails when its exit code is not accepted.

.DESCRIPTION
    Invokes a native command and fails when its exit code is not accepted.

    Includes a workaround for the issue where the PSModulePath is incorrect
    when calling an edition different than the current one (e.g. calling pwsh
    from Windows PowerShell).

.EXAMPLE
    Basic usage:

    Invoke-PleaseWorkNativeCommand cmd '/c', 'echo Hello World'

.EXAMPLE
    Basic usage with a custom success exit code:

    Invoke-PleaseWorkNativeCommand cmd '/c', 'echo Hello World' -SuccessExitCode @(0, 1)

.EXAMPLE
    Invoke a native command using normal PowerShell syntax:

    Invoke-PleaseWorkNativeCommand { dotnet restore }
#>
function Invoke-PleaseWorkNativeCommand {
    [CmdletBinding(DefaultParameterSetName='FilePath')]
    [Alias('exec')]
    param (
        [Parameter(Mandatory,Position=0,ParameterSetName='FilePath')]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath,

        [Parameter(Position=1,ValueFromRemainingArguments,ParameterSetName='FilePath')]
        [object[]] $ArgumentList = @(),

        [Parameter(Mandatory,Position=0,ParameterSetName='ScriptBlock')]
        [ValidateNotNull()]
        [scriptblock] $ScriptBlock,

        [Parameter()]
        [int[]] $SuccessExitCode = @(0)
    )

    # Normalize the edition specific PSModulePath so a call to powershell or
    # pwsh can find modules in the expected user module path.
    $OriginalPSModulePath = $env:PSModulePath
    try {
        $NormalizePowerShellModulePath = -not (
            $null -ne $script:PleaseWorkConfig -and
            $script:PleaseWorkConfig.Contains('NormalizePowerShellModulePath') -and
            $script:PleaseWorkConfig['NormalizePowerShellModulePath'] -eq $false
        )

        if ($PSCmdlet.ParameterSetName -eq 'FilePath') {
            $PowerShellCommandName = [IO.Path]::GetFileNameWithoutExtension($FilePath)
        } elseif ($PSEdition -eq 'Core' -and -not ($IsLinux -or $IsMacOS)) {
            $PowerShellCommandName = 'powershell'
        } elseif ($PSEdition -eq 'Desktop') {
            $PowerShellCommandName = 'pwsh'
        }

        if ($NormalizePowerShellModulePath -and $PowerShellCommandName -in @('powershell', 'pwsh')) {
            $UserModulePath = if ($PowerShellCommandName -eq 'pwsh' -and ($IsLinux -or $IsMacOS)) {
                Join-Path $HOME '.local/share/powershell/Modules'
            } else {
                $UserModuleDirectoryName = if ($PowerShellCommandName -eq 'powershell') {
                    'WindowsPowerShell'
                } else {
                    'PowerShell'
                }
                Join-Path `
                    ([Environment]::GetFolderPath('MyDocuments')) `
                    "$UserModuleDirectoryName\Modules"
            }
            $ModulePaths = @($env:PSModulePath -split [IO.Path]::PathSeparator)

            if ((Test-Path -LiteralPath $UserModulePath) -and $UserModulePath -notin $ModulePaths) {
                $env:PSModulePath = $UserModulePath + [IO.Path]::PathSeparator + $env:PSModulePath
            }
        }

        $global:LASTEXITCODE = 0
        if ($PSCmdlet.ParameterSetName -eq 'ScriptBlock') {
            & $ScriptBlock
        } else {
            & $FilePath @ArgumentList
        }
        $ExitCode = [int] $global:LASTEXITCODE
    } finally {
        $env:PSModulePath = $OriginalPSModulePath
    }

    if ($SuccessExitCode -notcontains $ExitCode) {
        $CommandDescription = if ($PSCmdlet.ParameterSetName -eq 'ScriptBlock') {
            'script block'
        } else {
            $FilePath
        }
        $Exception = [System.ComponentModel.Win32Exception]::new(
            $ExitCode,
            "Native command '$CommandDescription' exited with code $ExitCode."
        )
        $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
            $Exception,
            'PleaseWork.NativeCommandFailed',
            [System.Management.Automation.ErrorCategory]::NotSpecified,
            $(if ($PSCmdlet.ParameterSetName -eq 'ScriptBlock') { $ScriptBlock } else { $FilePath })
        )
        $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }

    # The task runner reads the runspace's global LASTEXITCODE after the task
    # completes. Normalize an accepted nonzero code so it does not subsequently
    # mark an otherwise successful task failed.
    $global:LASTEXITCODE = 0
}
