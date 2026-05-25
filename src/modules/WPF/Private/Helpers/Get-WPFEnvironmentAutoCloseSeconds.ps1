function Get-WPFEnvironmentAutoCloseSeconds {
    [CmdletBinding()]
    [OutputType([System.Nullable[double]])]
    param()

    if ([string]::IsNullOrWhiteSpace($env:WPF_AUTO_CLOSE_SECONDS)) {
        return $null
    }

    $ParsedAutoCloseSeconds = 0.0
    if ([double]::TryParse($env:WPF_AUTO_CLOSE_SECONDS, [ref] $ParsedAutoCloseSeconds)) {
        return [double] $ParsedAutoCloseSeconds
    }

    Write-Warning "Ignoring WPF_AUTO_CLOSE_SECONDS because it is not a valid number: '$($env:WPF_AUTO_CLOSE_SECONDS)'"
    return $null
}
