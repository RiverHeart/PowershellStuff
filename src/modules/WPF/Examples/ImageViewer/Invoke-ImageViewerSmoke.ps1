<#
.SYNOPSIS
    Runs ImageViewer in unattended smoke mode.

.DESCRIPTION
    Wrapper for ImageViewer.DSL.ps1 that enables unattended execution through
    startup automation (open file, start slideshow, auto-close).
#>
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $FilePath,

    [Parameter()]
    [ValidateRange(0.5, 600)]
    [double] $SlideshowIntervalSeconds = 2.0,

    [Parameter()]
    [ValidateRange(0.5, 600)]
    [double] $AutoCloseSeconds = 10.0,

    [Parameter()]
    [switch] $StartFullscreen
)

if ($PSScriptRoot -and $PWD -ne $PSScriptRoot) {
    Set-Location $PSScriptRoot
}

$InvocationArgs = @{
    SlideshowIntervalSeconds = $SlideshowIntervalSeconds
    AutoCloseSeconds         = $AutoCloseSeconds
}

if ($FilePath) {
    $InvocationArgs.FilePath = $FilePath
}

if ($StartFullscreen) {
    $InvocationArgs.StartFullscreen = $true
}

& "$PSScriptRoot/ImageViewer.DSL.ps1" @InvocationArgs
