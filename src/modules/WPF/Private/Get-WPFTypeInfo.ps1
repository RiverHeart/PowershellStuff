<#
.SYNOPSIS
    Returns all WPF types from the PresentationFramework assembly.

.DESCRIPTION
    Returns all WPF types from the PresentationFramework assembly.

    The function attempts to get a reference to the assembly by
    accessing a well known type. If the assembly is available, then
    we return `ExportedTypes` filtering if necessary.

.EXAMPLE
    Get all types

    Get-WPFTypeInfo

.EXAMPLE
    Get the button type

    Get-WPFTypeInfo 'Button'
#>
function Get-WPFTypeInfo {
    [OutputType([type])]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    try {
        $Assembly = [System.Reflection.Assembly]::GetAssembly([System.Windows.Controls.Button])
    } catch {
        Write-Error "Failed to access assembly. Forgot to run `Add-Type PresentationFramework`?`nError: $_"
        return
    }
    $Assembly.ExportedTypes | Where-Object { $_.Name -ieq $Name }
}
