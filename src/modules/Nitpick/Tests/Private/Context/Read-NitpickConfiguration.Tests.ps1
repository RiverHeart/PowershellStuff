BeforeAll {
    Import-Module "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module Nitpick -Force -ErrorAction SilentlyContinue
}

# Content validation is tested in memory in New-NitpickConfiguration.Tests.ps1.
# These tests cover reading the file and passing its directory along.
Describe 'Read-NitpickConfiguration' {
    It 'returns validated configuration from a file' {
        InModuleScope Nitpick {
            $Path = Join-Path $TestDrive 'settings.psd1'
            Set-Content -LiteralPath $Path -Value @'
@{
    Compatibility = @{ PowerShell = @{ MinimumVersion = '5.1' } }
    Rules = @{
        'Nitpick/AvoidLongLines' = @{ MaximumLength = 100 }
    }
}
'@

            $Configuration = Read-NitpickConfiguration -LiteralPath $Path

            $Configuration.Compatibility.PowerShell.MinimumVersion | Should -Be ([version] '5.1')
            $Configuration.Rules['Nitpick/AvoidLongLines'].MaximumLength | Should -Be 100
        }
    }

    It 'names the configuration path once in content errors' {
        InModuleScope Nitpick {
            $Path = Join-Path $TestDrive 'typo.psd1'
            Set-Content -LiteralPath $Path -Value '@{ Typo = 1 }'

            $Thrown = { Read-NitpickConfiguration -LiteralPath $Path } |
                Should -Throw -ErrorId 'NitpickInvalidConfiguration*' -PassThru

            $Thrown.Exception.Message |
                Should -BeExactly "Invalid Nitpick configuration '$Path': Unknown configuration key 'Configuration.Typo'."
            $Thrown.TargetObject | Should -BeExactly $Path
        }
    }

    It 'rejects a file that is not data <Text>' -ForEach @(
        'throw "must not execute"', '@{ Compatibility =' | ForEach-Object { @{ Text = $_ } }
    ) {
        InModuleScope Nitpick -Parameters @{ Text = $Text } {
            param($Text)
            $Path = Join-Path $TestDrive 'malformed.psd1'
            Set-Content -LiteralPath $Path -Value $Text
            { Read-NitpickConfiguration -Path $Path } |
                Should -Throw -ErrorId 'NitpickInvalidConfiguration*'
        }
    }

    It 'resolves relative module paths from the configuration directory, not the caller location' {
        InModuleScope Nitpick {
            $ConfigDirectory = New-Item -Path (Join-Path $TestDrive 'project\config') -ItemType Directory
            $Elsewhere = New-Item -Path (Join-Path $TestDrive 'elsewhere') -ItemType Directory
            $Path = Join-Path $ConfigDirectory.FullName 'nitpick.psd1'
            Set-Content -LiteralPath $Path -Value "@{ Modules = 'WPF', '.\rules\Custom.psd1' }"

            Push-Location -LiteralPath $Elsewhere.FullName
            try {
                $Modules = (Read-NitpickConfiguration -LiteralPath $Path).Modules
            } finally {
                Pop-Location
            }

            $Modules | Should -Be @('WPF', (Join-Path $ConfigDirectory.FullName 'rules\Custom.psd1'))
        }
    }

    It 'rejects Nitpick''s own module manifest with a specific message' {
        InModuleScope Nitpick {
            $ManifestPath = Join-Path (Get-Module Nitpick).ModuleBase 'Nitpick.psd1'
            { Read-NitpickConfiguration -LiteralPath $ManifestPath } |
                Should -Throw '*looks like a PowerShell module manifest*'
        }
    }

    It 'accepts a literal relative filename' {
        InModuleScope Nitpick {
            $Path = Join-Path $TestDrive 'policy[1].psd1'
            Set-Content -LiteralPath $Path -Value '@{ Compatibility = @{ PowerShell = @{ MinimumVersion = "5.1" } } }'
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
