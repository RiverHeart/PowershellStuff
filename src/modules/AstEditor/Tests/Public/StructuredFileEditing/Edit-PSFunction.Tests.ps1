using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot/../../../AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module -Name AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'Edit-PSFunction' {
    It 'accepts an existing AstDocument without coercing it to a string' {
        $Document = New-AstDocument -InputObject 'function foo { Write-Host foo }'

        $Result = Edit-PSFunction `
            -InputObject $Document `
            -Name foo `
            -Replacement 'function foo { Write-Host fubar }'

        $Result.Document | Should -Be $Document
        $Result.RenderedText | Should -Be 'function foo { Write-Host fubar }'
    }

    It 'accepts a ScriptBlock and finds functions within its normalized AST' {
        $Result = Edit-PSFunction `
            -InputObject { function foo { Write-Host foo } } `
            -Name foo `
            -Replacement 'function foo { Write-Host fubar }'

        $Result.ParseErrorCount | Should -Be 0
        $Result.RenderedText | Should -Match 'function foo \{ Write-Host fubar \}'
    }

    It 'returns a preview without changing the file by default' {
        $Path = Join-Path $TestDrive 'Preview.ps1'
        "function Get-Greeting { 'old' }" | Set-Content -LiteralPath $Path -NoNewline

        $Result = Edit-PSFunction `
            -Path $Path `
            -Name Get-Greeting `
            -Replacement "function Get-Greeting { 'new' }"

        $Result.Applied | Should -BeFalse
        $Result.ParseErrorCount | Should -Be 0
        $Result.EditCount | Should -Be 1
        $Result.Diff | Should -Match "function Get-Greeting \{ 'new' \}"
        [System.IO.File]::ReadAllText($Path) | Should -Be "function Get-Greeting { 'old' }"
    }

    It 'writes the validated replacement only when Apply is specified' {
        $Path = Join-Path $TestDrive 'Apply.ps1'
        "function Get-Greeting { 'old' }" | Set-Content -LiteralPath $Path -NoNewline

        $Result = Edit-PSFunction `
            -Path $Path `
            -Name Get-Greeting `
            -Replacement "function Get-Greeting { 'new' }" `
            -Apply `
            -Confirm:$false

        $Result.Applied | Should -BeTrue
        [System.IO.File]::ReadAllText($Path) | Should -Be "function Get-Greeting { 'new' }"
    }

    It 'does not write when Apply and WhatIf are used together' {
        $Path = Join-Path $TestDrive 'WhatIf.ps1'
        "function Get-Greeting { 'old' }" | Set-Content -LiteralPath $Path -NoNewline

        $Result = Edit-PSFunction `
            -Path $Path `
            -Name Get-Greeting `
            -Replacement "function Get-Greeting { 'new' }" `
            -Apply `
            -WhatIf

        $Result.Applied | Should -BeFalse
        $Result.Diff | Should -Match "function Get-Greeting \{ 'new' \}"
        [System.IO.File]::ReadAllText($Path) | Should -Be "function Get-Greeting { 'old' }"
    }
}
