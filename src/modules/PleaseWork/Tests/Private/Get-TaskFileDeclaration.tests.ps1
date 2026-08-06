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

        It 'separates task dependencies from changed pathspecs' {
            $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
            @'
build: test changed('./Public', './Private') { 'build' }
test: { 'test' }
'@ | Set-Content -LiteralPath $TaskFile

            $Declaration = @(Get-TaskFileDeclaration -Path $TaskFile)[0]

            $Declaration.Dependencies | Should -Be @('test')
            $Declaration.PathSpecs | Should -Be @('./Public', './Private')
        }

        It 'rejects nonliteral changed pathspecs' {
            $TaskFile = Join-Path $TestDrive 'TaskFile.ps1'
            "build: changed(`$Path) { 'build' }" | Set-Content -LiteralPath $TaskFile

            { Get-TaskFileDeclaration -Path $TaskFile } |
                Should -Throw "Changeset filters for task 'build' must contain only string pathspecs."
        }
    }
}

