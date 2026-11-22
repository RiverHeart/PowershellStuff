BeforeAll {
    Import-Module "$PSScriptRoot/../../../AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module -Name AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'Format-AstTree' {
    It 'aligns multiline text beneath a terminal branch' {
        $Lines = @(
            {
                Write-Host 'Hello'
                Write-Host 'World'
            }.Ast | Format-AstTree
        )

        $Lines[0] | Should -BeExactly 'ScriptBlockAst'
        $Lines[1] | Should -BeExactly '`-- NamedBlockAst'
        $Lines[2] | Should -BeExactly "    >> Write-Host 'Hello'"
        $Lines[3] | Should -BeExactly "    >> Write-Host 'World'"
        $Lines[4] | Should -BeExactly '    |-- PipelineAst  <<  Write-Host ''Hello'''
    }

    It 'draws connector continuations between sibling branches' {
        $Lines = @(
            {
                Write-Host 'Hello'
                Write-Host 'World'
            }.Ast | Format-AstTree
        )

        @($Lines | Where-Object { $_ -like '*PipelineAst*' }) |
            Should -HaveCount 2
        $Lines | Should -Contain '    `-- PipelineAst  <<  Write-Host ''World'''
    }

    It 'does not display children when depth is zero' {
        $Lines = @(
            { Write-Host 'Hello' }.Ast |
                Format-AstTree -Depth 0
        )

        $Lines | Should -HaveCount 1
        $Lines[0] | Should -BeExactly 'ScriptBlockAst'
    }
}
