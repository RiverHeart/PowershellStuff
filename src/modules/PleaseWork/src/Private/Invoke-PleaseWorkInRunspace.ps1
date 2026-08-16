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

    $Runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $PowerShell = [powershell]::Create()
    try {
        $Runspace.Open()
        $PowerShell.Runspace = $Runspace
        $InvocationScript = {
            param ($ImportedModulePath, $Parameters, $InitialWorkingDirectory)

            Set-Location -LiteralPath $InitialWorkingDirectory
            Import-Module -Name $ImportedModulePath -Force -ErrorAction Stop
            Invoke-PleaseWork @Parameters
        }
        $null = $PowerShell.AddScript($InvocationScript.ToString())
        $null = $PowerShell.AddArgument($ModulePath)
        $null = $PowerShell.AddArgument($InvocationParameters)
        $null = $PowerShell.AddArgument($WorkingDirectory)

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
        $Output

        if ($null -ne $InvocationError) {
            throw $InvocationError
        }
        if ($PowerShell.InvocationStateInfo.State -eq 'Failed') {
            throw $PowerShell.InvocationStateInfo.Reason
        }
    } finally {
        $PowerShell.Dispose()
        $Runspace.Dispose()
    }
}
