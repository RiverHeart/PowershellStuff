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
#>
function Invoke-PleaseWorkNativeCommand {
    [CmdletBinding()]
    [Alias('exec')]
    param (
        [Parameter(Mandatory,Position=0)]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath,

        [Parameter(Position=1,ValueFromRemainingArguments)]
        [object[]] $ArgumentList = @(),

        [Parameter()]
        [int[]] $SuccessExitCode = @(0)
    )

    # Normalize the edition specific PSModulePath so a call to powershell or
    # pwsh can find modules in the expected user module path.
    $OriginalPSModulePath = $env:PSModulePath
    try {
        $CommandName = [IO.Path]::GetFileNameWithoutExtension($FilePath)
        $NormalizePowerShellModulePath = -not (
            $null -ne $script:PleaseWorkConfig -and
            $script:PleaseWorkConfig.Contains('NormalizePowerShellModulePath') -and
            $script:PleaseWorkConfig['NormalizePowerShellModulePath'] -eq $false
        )

        if ($NormalizePowerShellModulePath -and $CommandName -in @('powershell', 'pwsh')) {
            $UserModulePath = if ($CommandName -eq 'pwsh' -and ($IsLinux -or $IsMacOS)) {
                Join-Path $HOME '.local/share/powershell/Modules'
            } else {
                $UserModuleDirectoryName = if ($CommandName -eq 'powershell') {
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

        & $FilePath @ArgumentList
        $ExitCode = [int] $global:LASTEXITCODE
    } finally {
        $env:PSModulePath = $OriginalPSModulePath
    }

    if ($SuccessExitCode -notcontains $ExitCode) {
        $Exception = [System.ComponentModel.Win32Exception]::new(
            $ExitCode,
            "Native command '$FilePath' exited with code $ExitCode."
        )
        $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
            $Exception,
            'PleaseWork.NativeCommandFailed',
            [System.Management.Automation.ErrorCategory]::NotSpecified,
            $FilePath
        )
        $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }

    # The task runner reads the runspace's global LASTEXITCODE after the task
    # completes. Normalize an accepted nonzero code so it does not subsequently
    # mark an otherwise successful task failed.
    $global:LASTEXITCODE = 0
}
