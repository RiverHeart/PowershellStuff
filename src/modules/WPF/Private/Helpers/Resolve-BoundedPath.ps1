<#
.SYNOPSIS
    Resolves a path against a base path and ensures it stays within the base path.

.DESCRIPTION
    This function takes a base path and a bounded path, resolves the full path, and checks if the resulting path is within the base path. If the resolved path is outside the base path, an error is thrown.

.EXAMPLE
    Resolve-BoundedPath -BasePath "C:\MyApp" -BoundedPath "src\Views\main.gui.ps1"
#>
function Resolve-BoundedPath {
    param(
        [Parameter(Mandatory)]
        [string] $BasePath,

        [Parameter(Mandatory)]
        [string] $BoundedPath
    )

    $FullBasePath = [System.IO.Path]::GetFullPath($BasePath)

    if ([System.IO.Path]::IsPathRooted($BoundedPath)) {
        $FullPath = [System.IO.Path]::GetFullPath($BoundedPath)
    } else {
        $FullPath = [System.IO.Path]::GetFullPath((Join-Path $FullBasePath $BoundedPath))
    }

    if (-not ($FullPath.StartsWith($FullBasePath, [System.StringComparison]::OrdinalIgnoreCase))) {
        Write-Error "Resolved path '$FullPath' is outside the base path '$FullBasePath'."
        return
    }

    return $FullPath
}
