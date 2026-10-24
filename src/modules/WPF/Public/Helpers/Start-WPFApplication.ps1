<#
.SYNOPSIS
    Starts a WPF application entry point inside an application module's scope.

.DESCRIPTION
    Imports an application module and dot-sources an entry point in that module's
    session state. The entry point can therefore call functions that the application
    module does not export.

.EXAMPLE
    Start-WPFApplication -ModulePath ./MyApp.psd1 -EntryPoint src/Views/main.gui.ps1 -Force
#>
function Start-WPFApplication {
    [CmdletBinding(DefaultParameterSetName="ByPath")]
    param(
        [Parameter(Mandatory,ParameterSetName="ByName")]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [Parameter(Mandatory,ParameterSetName="ByPath")]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo] $ModulePath,

        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo] $EntryPoint,

        [switch] $Force
    )

    if ($PSCmdlet.ParameterSetName -eq "ByName") {
        $Module = Get-Module -Name $Name -ListAvailable |
            Where-Object { $_.Tags -contains "WPFApplication" }
            Select-Object -First 1

        if (-not $Module) {
            Write-Error "Application module '$Name' was not found."
            return
        }
    } else {
        if (-not $ModulePath.Exists) {
            Write-Error "Application module '$ModulePath' was not found."
            return
        }

        $ResolvedModulePath = Resolve-Path -LiteralPath $ModulePath -ErrorAction Stop
        $Module = Import-Module -Name $ResolvedModulePath.ProviderPath -PassThru -Force:$Force -ErrorAction Stop
    }

    if (-not $EntryPoint) {
        $EntryPoint = $Module.PrivateData.Application.EntryPoint
    }

    $EntryPoint = Resolve-BoundedPath -BasePath $Module.ModuleBase -BoundedPath $EntryPoint -ErrorAction Stop

    if (-not $EntryPoint.Exists) {
        Write-Error "Application entry point '$EntryPoint' was not found."
        return
    }

    & $Module {
        param($Path)

        . $Path
    } $EntryPoint
}
