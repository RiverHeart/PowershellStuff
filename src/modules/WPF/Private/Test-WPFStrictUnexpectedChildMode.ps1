function Test-WPFStrictUnexpectedChildMode {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $value = [Environment]::GetEnvironmentVariable('WPF_STRICT_UNEXPECTED_CHILD')
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $false
    }

    return [bool] ($value.Trim() -match '^(?i:1|true|yes|on)$')
}
