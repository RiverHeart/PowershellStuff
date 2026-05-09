function Test-WPFSmokeTestMode {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($env:WPF_SMOKE_TEST -is [bool]) {
        return $env:WPF_SMOKE_TEST
    }
    if ([string]::IsNullOrWhiteSpace($env:WPF_SMOKE_TEST)) {
        return $false
    }

    return [bool] ($env:WPF_SMOKE_TEST.Trim() -match '^(?i:1|true|yes|on)$')
}
