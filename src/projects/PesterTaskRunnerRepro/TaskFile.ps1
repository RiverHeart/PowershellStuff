test: {
    $TestPaths = @(
        Join-Path $TaskFileRoot 'Tests\ModuleCleanup.Tests.ps1'
        Join-Path $TaskFileRoot 'Tests\ModuleCleanupReference.Tests.ps1'
    )
    Import-Module -Name Pester -MinimumVersion '5.0.0' -ErrorAction Stop

    $Result = Invoke-Pester -Path $TestPaths -PassThru -Output Detailed
    if ($Result.Result -ne 'Passed') {
        throw "Pester result was '$($Result.Result)'."
    }
}
