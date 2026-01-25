if ($PWD -ne $PSScriptRoot) {
    Set-Location $PSScriptRoot
}

Invoke-Pester -Path "$PSScriptRoot/Tests"
