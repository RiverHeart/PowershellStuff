BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Assert-CallableSignature' {
    It 'accepts a scriptblock containing all required parameters' {
        {
            InModuleScope Nitpick {
                Assert-CallableSignature `
                    -TargetCallable { param ($ScriptBlockAst, $FilePath) } `
                    -RequiredParams 'ScriptBlockAst', 'FilePath'
            }
        } | Should -Not -Throw
    }

    It 'accepts a command containing the required parameter' {
        {
            InModuleScope Nitpick {
                Assert-CallableSignature `
                    -TargetCallable (Get-Command -Name Get-ChildItem -CommandType Cmdlet) `
                    -RequiredParams 'Path'
            }
        } | Should -Not -Throw
    }

    It 'reports all missing required parameters' {
        {
            InModuleScope Nitpick {
                Assert-CallableSignature `
                    -TargetCallable { param ($ScriptBlockAst) } `
                    -RequiredParams 'ScriptBlockAst', 'FilePath', 'Settings'
            }
        } | Should -Throw '*Missing required parameter(s): FilePath, Settings*'
    }
}
