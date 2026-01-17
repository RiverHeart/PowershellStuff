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
    $ProfileDirPath = "$Parent/Profile.d"
    if (-not (Test-Path -Path $ProfileDirPath -PathType Container)) {
        New-Item -Path $ProfileDirPath -ItemType Directory
    }

    $ProfileTemplate = @"
`$PROFILE_DOT_D=`"$ProfileDirPath`"
foreach(`$Fragment in (Get-ChildItem `$PROFILE_DOT_D)) {
    Write-Verbose "Sourcing: `$Fragment"
    #. `$Fragment
}
"@

    if (-not (Test-Path -Path $PROFILE)) {
        New-Item -Path $PROFILE -ItemType File
    }

    if (Get-Variable 'PROFILE_DOT_D' -ErrorAction Ignore) {
        Write-Host "Profile '$ProfileName' already configured."
    } else {
        Write-Host "Updating profile '$Profilename'"
        Add-Content -Value $ProfileTemplate -Path $PROFILE
    }
}
