using namespace System.Management.Automation.Runspaces

$ErrorActionPreference = 'Stop'

function Invoke-CommandWithSuppression {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,

        [switch] $AllowStandard,
        [switch] $AllowWhatIfOutput,
        [switch] $AllowError,
        [switch] $AllowWarning,
        [switch] $AllowVerbose,
        [switch] $AllowInformation,
        [switch] $AllowProgress,
        [switch] $AllowDebug
    )

    try {
        if (-not ('SuppressablePSHost' -as [type])) {
            $Source = Get-Content -Raw "$PSScriptRoot\SilentPSHost.cs"
            Add-Type -ErrorAction Stop -TypeDefinition $Source -Language CSharp
        }

        $SilentHost = [SuppressablePSHost]::new($Host)
        $SilentHost.UI.AllowStandard = $AllowStandard
        $SilentHost.UI.AllowWhatIf = $AllowWhatIfOutput
        $SilentHost.UI.AllowError = $AllowError
        $SilentHost.UI.AllowWarning = $AllowWarning
        $SilentHost.UI.AllowVerbose = $AllowVerbose
        $SilentHost.UI.AllowInformation = $AllowInformation
        $SilentHost.UI.AllowProgress = $AllowProgress
        $SilentHost.UI.AllowDebug = $AllowDebug

        $InitialSessionState = [InitialSessionState]::CreateDefault()

        $Runspace = [RunspaceFactory]::CreateRunspace($SilentHost, $InitialSessionState)
        $Runspace.Open()

        $Powershell = [PowerShell]::Create()
        $Powershell.Runspace = $Runspace

        [void] $Powershell.AddScript($ScriptBlock, <# useLocalScope #> $true)

        $Results = $Powershell.Invoke()
        if ($Powershell.HadErrors) {
            $Powershell.Streams.Error | Write-Error
        }

        $Results | Format-Table

    } finally {
        if ($Runspace) { $Runspace.Dispose() }
        if ($Powershell) { $Powershell.Dispose() }
    }
}


$Config = @{
    AllowStandard = $false
    AllowWhatIf = $false
    AllowVerbose = $false
    AllowDebug = $true
    AllowError = $false
    AllowWarning = $false
    AllowInformation = $false
    AllowProgress = $false
}

Invoke-CommandWithSuppression @Config -ScriptBlock {
    function Test-Function {
        [CmdletBinding(SupportsShouldProcess)]
        param()

        Write-Host 'Suppressed standard'
        Write-Warning 'Suppressed warning'
        Write-Verbose 'Suppressed verbose'
        Write-Debug 'Suppressed debug'

        if ($PSCmdlet.ShouldProcess('Test-Function')) {
            Write-Host 'Processing Test-Function'
        }

        return [pscustomobject]@{
            Message = 'Foobar'
        }
    }

    Test-Function -Verbose -Debug -WhatIf
}.GetNewClosure()
