using namespace System.Management.Automation.Runspaces

$ErrorActionPreference = 'Stop'

try {
    $Source = Get-Content -Raw "$PSScriptRoot\SilentPSHost.cs"

    Add-Type -ErrorAction Stop -TypeDefinition $Source -Language CSharp

    $SilentHost = [SilentPSHost]::new($Host)

    $InitialSessionState = [InitialSessionState]::CreateDefault()

    $Runspace = [RunspaceFactory]::CreateRunspace($SilentHost, $InitialSessionState)
    $Runspace.Open()

    $Powershell = [PowerShell]::Create()
    $Powershell.Runspace = $Runspace

    [void] $Powershell.AddScript({
        Write-Host 'Suppressed output'
        Write-Warning 'Suppressed warning'

        return [pscustomobject]@{
            Message = 'Foobar'
        }
    })

    $Results = $Powershell.Invoke()
    if ($Powershell.HadErrors) {
        $Powershell.Streams.Error | Write-Error
    }

    $Results | Format-Table

} finally {
    if ($Runspace) { $Runspace.Dispose() }
    if ($Powershell) { $Powershell.Dispose() }
}
