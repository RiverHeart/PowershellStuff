BeforeAll {
    Import-Module "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Read-NitpickConfiguration' {
    It 'normalizes supported release <Release>' -ForEach @(
        '5.1',
        '6.0', '6.1', '6.2',
        '7.0', '7.1', '7.2', '7.3', '7.4', '7.5', '7.6' |
        ForEach-Object { @{ Release = $_ } }
    ) {
        param($Release)
        InModuleScope Nitpick -Parameters @{ Release = $Release } {
            param($Release)
            $Path = Join-Path $TestDrive 'nitpick.psd1'
            Set-Content -LiteralPath $Path -Value "@{ Compatibility = @{ PowerShell = @{ MinimumVersion = '$Release' } } }"

            $Policy = Read-NitpickConfiguration -Path $Path

            $Policy.Compatibility.PowerShell.MinimumVersion | Should -BeOfType ([version])
            $Policy.Compatibility.PowerShell.MinimumVersion.ToString() | Should -BeExactly $Release
            $Policy.Compatibility.PowerShell.MinimumVersion.Build | Should -Be -1
        }
    }

    It 'rejects invalid minimum <Expression>' -TestCases @(
        "'5'", "'5.0'", "'7'", "'7.4.0'", "'7.4-preview.1'", "' 7.4'", "'7.4 '",
        '7.4', '7', "'99.0'", "'6.3'", "'7.7'", "''", '$null', '$false', '@()', '@{}' |
            ForEach-Object { @{ Expression = $_ } }
    ) {
        param($Expression)
        InModuleScope Nitpick -Parameters @{ Expression = $Expression } {
            param($Expression)
            $Path = Join-Path $TestDrive 'invalid.psd1'
            Set-Content -LiteralPath $Path -Value "@{ Compatibility = @{ PowerShell = @{ MinimumVersion = $Expression } } }"

            { Read-NitpickConfiguration -Path $Path } |
                Should -Throw -ErrorId 'NitpickInvalidConfiguration*'
        }
    }

    It 'normalizes empty policy <Text>' -TestCases @(
        '@{}', '@{ Compatibility = @{} }', '@{ Compatibility = @{ PowerShell = @{} } }' |
            ForEach-Object { @{ Text = $_ } }
    ) {
        param($Text)
        InModuleScope Nitpick -Parameters @{ Text = $Text } {
            param($Text)
            $Path = Join-Path $TestDrive 'empty.psd1'
            Set-Content -LiteralPath $Path -Value $Text
            $Policy = Read-NitpickConfiguration -Path $Path
            $Policy | Should -BeOfType ([hashtable])
            $Policy.Count | Should -Be 0
        }
    }

    It 'rejects malformed or unknown schema <Text>' -TestCases @(
        '@{ Compatibility = $null }',
        '@{ Compatibility = 1 }',
        '@{ Compatibility = @() }',
        '@{ Compatibility = @{ PowerShell = $null } }',
        '@{ Compatibility = @{ PowerShell = "5.1" } }',
        '@{ Compatibility = @{ PowerShell = @() } }',
        '@{ Rules = @{} }',
        '@{ Keys = @() }',
        '@{ Compatibility = @{ Keys = @() } }',
        '@{ Compatibility = @{ PowerShell = @{ Keys = @() } } }',
        '@{ Caller = "spoofed" }',
        '@{ Compatibility = @{ Typo = @{} } }',
        '@{ Compatibility = @{ PowerShell = @{ MinVersion = "5.1" } } }',
        '@{ Compatibility = @{ PowerShell = @{}; Typo = 1 } }',
        '@{ 1 = @{} }',
        'throw "must not execute"',
        '@{ Compatibility =' |
            ForEach-Object { @{ Text = $_ } }
    ) {
        param($Text)
        InModuleScope Nitpick -Parameters @{ Text = $Text } {
            param($Text)
            $Path = Join-Path $TestDrive 'malformed.psd1'
            Set-Content -LiteralPath $Path -Value $Text
            { Read-NitpickConfiguration -Path $Path } |
                Should -Throw -ErrorId 'NitpickInvalidConfiguration*'
        }
    }

    It 'accepts case-insensitive keys and a literal relative filename' {
        InModuleScope Nitpick {
            $Path = Join-Path $TestDrive 'policy[1].psd1'
            Set-Content -LiteralPath $Path -Value '@{ compatibility = @{ powershell = @{ minimumversion = "5.1" } } }'
            Push-Location $TestDrive
            try {
                $Policy = Read-NitpickConfiguration -LiteralPath '.\policy[1].psd1'
                $Policy.Compatibility.PowerShell.MinimumVersion | Should -Be ([version] '5.1')
            } finally {
                Pop-Location
            }
        }
    }

    It 'rejects a missing path, a directory, a provider path, and empty paths' {
        InModuleScope Nitpick {
            foreach ($Path in @((Join-Path $TestDrive 'missing.psd1'), $TestDrive, 'Env:\PATH', '', $null)) {
                { Read-NitpickConfiguration -Path $Path } |
                    Should -Throw -ErrorId 'NitpickInvalidConfiguration*'
            }
        }
    }

    It 'terminates when the file cannot be read' {
        InModuleScope Nitpick {
            $Path = Join-Path $TestDrive 'locked.psd1'
            Set-Content -LiteralPath $Path -Value '@{}'
            $Lock = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            try {
                { Read-NitpickConfiguration -Path $Path } |
                    Should -Throw -ErrorId 'NitpickInvalidConfiguration*'
            } finally {
                $Lock.Dispose()
            }
        }
    }
}
