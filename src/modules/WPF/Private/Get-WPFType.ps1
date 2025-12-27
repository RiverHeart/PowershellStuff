function Get-WPFType {
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
