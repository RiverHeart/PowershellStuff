BeforeAll {
    Import-Module "$PSScriptRoot/.." -Force
}

Describe 'Export-PowershellDataFile' {
    It 'writes a psd1 that can be imported with nested values' {
        $Path = Join-Path -Path $TestDrive -ChildPath 'project.psd1'
        $InputObject = @{
            Name = 'WPF'
            DevDependencies = @{
                Pester = '^5.7.1'
                'Thread Job' = '^2.0.3'
            }
            Flags = @($true, $false)
            Values = @($null, 42, 'text')
            Nested = @{ Inner = 'value' }
        }

        Export-PowershellDataFile -InputObject $InputObject -Path $Path

        $Imported = Import-PowerShellDataFile -Path $Path

        $Imported.Name | Should -Be 'WPF'
        $Imported.DevDependencies.Pester | Should -Be '^5.7.1'
        $Imported.DevDependencies['Thread Job'] | Should -Be '^2.0.3'
        $Imported.Flags.Count | Should -Be 2
        $Imported.Flags[0] | Should -BeTrue
        $Imported.Flags[1] | Should -BeFalse
        $Imported.Values.Count | Should -Be 3
        $Imported.Values[0] | Should -Be $null
        $Imported.Values[1] | Should -Be 42
        $Imported.Values[2] | Should -Be 'text'
        $Imported.Nested.Inner | Should -Be 'value'
    }

    It 'quotes non-identifier keys in output' {
        $Path = Join-Path -Path $TestDrive -ChildPath 'quoted-keys.psd1'
        $InputObject = @{
            'Thread Job' = '^2.0.3'
            "Owner's Name" = 'alex'
        }

        Export-PowershellDataFile -InputObject $InputObject -Path $Path

        $Content = Get-Content -Path $Path -Raw

        $Content | Should -Match "'Thread Job'\s*="
        $Content | Should -Match "'Owner''s Name'\s*="
    }

    It 'preserves empty arrays and empty hashtables' {
        $Path = Join-Path -Path $TestDrive -ChildPath 'empty-values.psd1'
        $InputObject = @{
            EmptyArray = @()
            EmptyMap = @{}
            Nested = @{
                EmptyArray = @()
                EmptyMap = @{}
            }
        }

        Export-PowershellDataFile -InputObject $InputObject -Path $Path

        $Imported = Import-PowerShellDataFile -Path $Path

        $Imported.ContainsKey('EmptyArray') | Should -BeTrue
        ($Imported.EmptyArray -is [array]) | Should -BeTrue
        $Imported.EmptyArray.Count | Should -Be 0

        $Imported.ContainsKey('EmptyMap') | Should -BeTrue
        $Imported.EmptyMap | Should -BeOfType ([hashtable])
        $Imported.EmptyMap.Count | Should -Be 0

        $Imported.Nested.ContainsKey('EmptyArray') | Should -BeTrue
        ($Imported.Nested.EmptyArray -is [array]) | Should -BeTrue
        $Imported.Nested.EmptyArray.Count | Should -Be 0

        $Imported.Nested.ContainsKey('EmptyMap') | Should -BeTrue
        $Imported.Nested.EmptyMap | Should -BeOfType ([hashtable])
        $Imported.Nested.EmptyMap.Count | Should -Be 0
    }
}
