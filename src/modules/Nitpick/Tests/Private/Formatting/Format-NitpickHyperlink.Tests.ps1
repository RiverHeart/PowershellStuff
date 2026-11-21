BeforeAll {
    Import-Module -Name "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Format-NitpickHyperlink' {
    BeforeEach {
        $PreviousEnvironment = @{
            FORCE_HYPERLINK = $env:FORCE_HYPERLINK
            NO_HYPERLINK = $env:NO_HYPERLINK
            TERM_PROGRAM = $env:TERM_PROGRAM
        }
        $env:FORCE_HYPERLINK = $null
        $env:NO_HYPERLINK = $null
        $env:TERM_PROGRAM = $null
    }

    AfterEach {
        $env:FORCE_HYPERLINK = $PreviousEnvironment.FORCE_HYPERLINK
        $env:NO_HYPERLINK = $PreviousEnvironment.NO_HYPERLINK
        $env:TERM_PROGRAM = $PreviousEnvironment.TERM_PROGRAM
    }

    It 'wraps the text in an OSC 8 link targeting the absolute URI when forced' {
        $env:FORCE_HYPERLINK = '1'
        $Path = Join-Path $TestDrive 'Example.ps1'

        $Text = InModuleScope Nitpick -Parameters @{ Path = $Path } {
            param ($Path)
            Format-NitpickHyperlink -Uri $Path -Text 'Example'
        }

        $Esc = [char] 27
        $Uri = [Uri]::new($Path).AbsoluteUri
        $Text | Should -BeExactly (@($Esc, ']8;;', $Uri, $Esc, '\', 'Example', $Esc, ']8;;', $Esc, '\') -join '')
    }

    It 'preserves a line:column fragment in the link target' {
        $env:FORCE_HYPERLINK = '1'
        $Uri = [Uri]::new((Join-Path $TestDrive 'Example.ps1')).AbsoluteUri

        $Text = InModuleScope Nitpick -Parameters @{ Uri = "$Uri#3:5" } {
            param ($Uri)
            Format-NitpickHyperlink -Uri $Uri -Text '3:5'
        }

        $Text | Should -Match ([regex]::Escape("]8;;$Uri#3:5"))
    }

    It 'returns the text unchanged when <Name>' -ForEach @(
        @{ Name = 'NO_HYPERLINK is set'; Variable = 'NO_HYPERLINK'; Value = '1' }
        @{ Name = 'FORCE_HYPERLINK is 0'; Variable = 'FORCE_HYPERLINK'; Value = '0' }
        @{ Name = 'running in VS Code'; Variable = 'TERM_PROGRAM'; Value = 'vscode' }
    ) {
        Set-Item -Path "Env:$Variable" -Value $Value

        $Text = InModuleScope Nitpick -Parameters @{ Path = (Join-Path $TestDrive 'Example.ps1') } {
            param ($Path)
            Format-NitpickHyperlink -Uri $Path -Text 'Example'
        }

        $Text | Should -BeExactly 'Example'
    }

    It 'returns the text unchanged without a URI even when forced' {
        $env:FORCE_HYPERLINK = '1'

        $Text = InModuleScope Nitpick {
            Format-NitpickHyperlink -Uri $null -Text '<ScriptBlock>'
        }

        $Text | Should -BeExactly '<ScriptBlock>'
    }
}
