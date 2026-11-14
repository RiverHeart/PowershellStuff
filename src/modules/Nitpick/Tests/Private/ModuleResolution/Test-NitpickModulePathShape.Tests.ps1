BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Test-NitpickModulePathShape' {
    It 'treats <Value> as path-shaped from syntax alone' -TestCases @(
        @{ Value = '.\Rules' }
        @{ Value = 'Rules/Custom' }
        @{ Value = 'FileSystem::C:\Rules' }
        @{ Value = 'Custom.psd1' }
        @{ Value = 'Custom.psm1' }
        @{ Value = 'Custom.dll' }
    ) {
        param($Value)
        InModuleScope Nitpick -Parameters @{ Value = $Value } {
            param($Value)
            Test-NitpickModulePathShape -Value $Value | Should -BeTrue
            Test-NitpickModulePathShape -Value $Value -SyntaxOnly | Should -BeTrue
        }
    }

    It 'treats a bare name as a path only when it exists and SyntaxOnly is not set' {
        InModuleScope Nitpick {
            $null = New-Item -Path (Join-Path $TestDrive 'ExistingRules') -ItemType Directory
            Push-Location -LiteralPath $TestDrive
            try {
                Test-NitpickModulePathShape -Value 'ExistingRules' | Should -BeTrue
                Test-NitpickModulePathShape -Value 'ExistingRules' -SyntaxOnly | Should -BeFalse
                Test-NitpickModulePathShape -Value 'MissingRules' | Should -BeFalse
            } finally {
                Pop-Location
            }
        }
    }
}
