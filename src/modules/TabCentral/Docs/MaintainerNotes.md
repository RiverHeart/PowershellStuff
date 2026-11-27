Leak with `Invoke-MDKTest` is fixed but for some reason direct Pester invocation with PSModulePath prepended causes 14 tests to fail.


```powershell
Import-Module .\src\modules\ModuleDevKit\ModuleDevKit.psd1 -Force
Import-Module Pester -MinimumVersion 5.7.1 -Force

$RepositoryModules = Join-Path (Get-Location) 'src\modules'
$env:PSModulePath = $RepositoryModules + [IO.Path]::PathSeparator + $env:PSModulePath

Invoke-Pester -Path .\src\modules\TabCentral\Tests -Output Normal
```
