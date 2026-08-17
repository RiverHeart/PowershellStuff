<#
.SYNOPSIS
    Creates a new PleaseWork runspace and powershell instance.

.NOTES
    TODO: Find a way to integrate with Invoke-PleaseWorkInRunspace
#>
function New-PleaseWorkTaskExecutor {
    [CmdletBinding()]
    [OutputType([powershell])]
    param(
        [scriptblock] $ScriptBlock,
        [object] $Parameters,
        [hashtable] $Variables = @{},
        [string] $WorkingDirectory
    )

    if ($null -ne $Parameters -and (
        $Parameters -isnot [System.Collections.IList] -or
        $Parameters -isnot [System.Collections.IDictionary]
    )) {
        Write-Error "`$Parameters must implement IList or IDictionary."
        return
    }

    try {
        $InitialSessionState = [initialsessionstate]::CreateDefault()

        # Add variables not already present in the session
        foreach ($VariableName in $Variables.GetEnumerator()) {
            $InitialSessionState.Variables.Add(
                [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new($_.Key, $_.Value, '')
            )
        }

        $Runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($InitialSessionState)

        # The SessionStateProxy allows us to set existing variables such as ErrorActionPreference
        # and modify the working directory without resorting to `InitialSessionState.StartupScripts`.
        $Runspace.Open()
        $Runspace.SessionStateProxy.SetVariable('ErrorActionPreference', 'Stop')
        if ($WorkingDirectory) {
            $Runspace.SessionStateProxy.Path.SetLocation($WorkingDirectory)
        }

        # Create a Powershell instance
        $Powershell = [powershell]::new($Runspace)
        $Powershell.AddScript($Scriptblock)
        if ($Parameters) {
            $Powershell.AddParameters($Parameters)
        }
    } catch {
        # Cleanup in the event that something fails
        if ($Powershell) { $Powershell.Dispose() }
        if ($Runspace) { $Runspace.Dispose() }
        throw
    }

    return $Powershell
}
