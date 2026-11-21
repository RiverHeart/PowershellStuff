using namespace System.Management.Automation.Language

BeforeAll {
    Import-Module "$PSScriptRoot/../../../AstEditor.psd1" -Force
}

AfterAll {
    Remove-Module -Name AstEditor -Force -ErrorAction SilentlyContinue
}

Describe 'Split-PSFunction' {
    It 'previews splitting all top-level functions without writing files' {
        $Path = Join-Path $TestDrive 'Module.psm1'
        $OutputDirectory = Join-Path $TestDrive 'Private'
        @'
function Get-One { 'one' }
function Get-Two { 'two' }
'@ | Set-Content -LiteralPath $Path -NoNewline

        $Result = Split-PSFunction -Path $Path -OutputDirectory $OutputDirectory

        $Result.Applied | Should -BeFalse
        $Result.Files.Name | Should -Be @('Get-One', 'Get-Two')
        $Result.EditCount | Should -Be 2
        $Result.ParseErrorCount | Should -Be 0
        Test-Path -LiteralPath $OutputDirectory | Should -BeFalse
        [System.IO.File]::ReadAllText($Path) | Should -Match 'Get-One'
    }

    It 'writes extracted files and removes functions from the source with Apply' {
        $Path = Join-Path $TestDrive 'Module.psm1'
        $OutputDirectory = Join-Path $TestDrive 'Private'
        @'
$ModuleName = 'Example'

function Get-One { 'one' }
function Get-Two { 'two' }
'@ | Set-Content -LiteralPath $Path -NoNewline

        $Result = Split-PSFunction `
            -Path $Path `
            -OutputDirectory $OutputDirectory `
            -Apply `
            -Confirm:$false

        $Result.Applied | Should -BeTrue
        [System.IO.File]::ReadAllText((Join-Path $OutputDirectory 'Get-One.ps1')) |
            Should -Be "function Get-One { 'one' }"
        [System.IO.File]::ReadAllText((Join-Path $OutputDirectory 'Get-Two.ps1')) |
            Should -Be "function Get-Two { 'two' }"
        [System.IO.File]::ReadAllText($Path) | Should -Match '\$ModuleName'
        [System.IO.File]::ReadAllText($Path) | Should -Not -Match 'function Get-'
    }

    It 'does not overwrite an existing function file without Force' {
        $Path = Join-Path $TestDrive 'Module.psm1'
        $OutputDirectory = Join-Path $TestDrive 'Private'
        $DestinationPath = Join-Path $OutputDirectory 'Get-One.ps1'
        $null = New-Item -ItemType Directory -Path $OutputDirectory -Force
        "function Get-One { 'original' }" | Set-Content -LiteralPath $Path -NoNewline
        'existing content' | Set-Content -LiteralPath $DestinationPath -NoNewline

        {
            Split-PSFunction `
                -Path $Path `
                -OutputDirectory $OutputDirectory `
                -Apply `
                -Confirm:$false
        } | Should -Throw "Destination file '$DestinationPath' already exists. Use Force to overwrite it."

        [System.IO.File]::ReadAllText($Path) | Should -Match 'function Get-One'
        [System.IO.File]::ReadAllText($DestinationPath) | Should -Be 'existing content'
    }

    It 'does not write the source or extracted files under WhatIf' {
        $Path = Join-Path $TestDrive 'WhatIfModule.psm1'
        $OutputDirectory = Join-Path $TestDrive 'WhatIfPrivate'
        "function Get-One { 'one' }" | Set-Content -LiteralPath $Path -NoNewline

        $Result = Split-PSFunction `
            -Path $Path `
            -OutputDirectory $OutputDirectory `
            -Apply `
            -WhatIf

        $Result.Applied | Should -BeFalse
        Test-Path -LiteralPath $OutputDirectory | Should -BeFalse
        [System.IO.File]::ReadAllText($Path) | Should -Match 'function Get-One'
    }
}
