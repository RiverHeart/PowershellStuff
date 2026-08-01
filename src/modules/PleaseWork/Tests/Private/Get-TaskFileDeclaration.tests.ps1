Import-Module "$PSScriptRoot/../../PleaseWork.psd1" -Force

InModuleScope PleaseWork {
    Describe 'Get-TaskFileDeclaration' {
        It 'returns ordered task metadata without executing task bodies' {
            $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
        @'
build: test lint { $global:PleaseWorkDeclarationExecuted = $true }
test: { 'test' }
lint: { 'lint' }
'@ | Set-Content -LiteralPath $TaskFile

            $Declarations = @(Get-TaskFileDeclaration -Path $TaskFile)

            $Declarations.Name | Should -Be @('build', 'test', 'lint')
            $Declarations[0].Dependencies | Should -Be @('test', 'lint')
            Get-Variable -Name PleaseWorkDeclarationExecuted -Scope Global -ErrorAction SilentlyContinue |
                Should -BeNullOrEmpty
        }
    }
}

