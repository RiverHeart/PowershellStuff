<#
.SYNOPSIS
    Creates ./profile.d and updates the active $PROFILE to
    source files from it if not already configured.
#>
function Initialize-ModularPSProfile {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $Parent = $PROFILE | Split-Path -Parent
    $ProfileName = $PROFILE | Split-Path -Leaf
    $ProfileDirPath = Join-Path -Path $Parent -ChildPath 'Profile.d'
    $EscapedProfileDirPath = $ProfileDirPath.Replace("'", "''")

    $ProfileBootstrapStart = '# >>> Initialize-ModularPSProfile >>>'
    $ProfileBootstrapEnd = '# <<< Initialize-ModularPSProfile <<<'

    if (-not (Test-Path -Path $ProfileDirPath -PathType Container)) {
        New-Item -Path $ProfileDirPath -ItemType Directory | Out-Null
    }

    $ProfileTemplate = @"
$ProfileBootstrapStart
`$PROFILE_DOT_D = '$EscapedProfileDirPath'
Get-ChildItem -Path `$PROFILE_DOT_D -File -Filter '*.ps1' | Sort-Object -Property Name | ForEach-Object {
    Write-Verbose ("Sourcing: {0}" -f `$_.FullName)
    . `$_.FullName
}
$ProfileBootstrapEnd
"@

    if (-not (Test-Path -Path $PROFILE)) {
        New-Item -Path $PROFILE -ItemType File | Out-Null
    }

    $ProfileContent = Get-Content -Path $PROFILE -Raw -ErrorAction Ignore

    if ($ProfileContent -match [regex]::Escape($ProfileBootstrapStart)) {
        Write-Host "Profile '$ProfileName' already configured."
    } else {
        Write-Host "Updating profile '$ProfileName'"
        Add-Content -Value $ProfileTemplate -Path $PROFILE
    }
}
