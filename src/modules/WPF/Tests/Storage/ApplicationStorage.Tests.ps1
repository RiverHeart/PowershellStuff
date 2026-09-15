Describe 'WPF application storage' -Tag 'Storage' {
    BeforeDiscovery {
        Import-Module -Name "$PSScriptRoot/../../WPF.psd1" -Force
    }

    BeforeEach {
        $Storage = New-WPFAppStorage `
            -Application 'StorageTests' `
            -Publisher 'TestPublisher' `
            -RootPath $TestDrive
    }

    It 'exports the storage commands' {
        $Commands = Get-Command `
            New-WPFAppStorage,
            Get-WPFStoredItem,
            Set-WPFStoredItem,
            Remove-WPFStoredItem

        $Commands.ModuleName | Should -Be @('WPF', 'WPF', 'WPF', 'WPF')
    }

    It 'creates an explicit application storage context' {
        $Storage.PSObject.TypeNames | Should -Contain 'WPF.ApplicationStorage'
        $Storage.RootPath | Should -Be (Join-Path $TestDrive 'TestPublisher\StorageTests')
        Test-Path -LiteralPath $Storage.RootPath -PathType Container | Should -BeTrue
    }

    It 'round-trips a CLIXML snapshot' {
        $Value = [pscustomobject] @{
            Name = 'Bulbasaur'
            Id   = 1
        }

        Set-WPFStoredItem -Storage $Storage -Name 'Pokemon' -Value $Value -Format CliXml
        $Actual = Get-WPFStoredItem -Storage $Storage -Name 'Pokemon' -Format CliXml

        $Actual.Name | Should -Be 'Bulbasaur'
        $Actual.Id | Should -Be 1
        Join-Path $Storage.RootPath 'Pokemon.clixml' | Should -Exist
    }

    It 'round-trips a JSON document by default' {
        $Value = @(
            [pscustomobject] @{
                Name = 'Bulbasaur'
                Id   = 1
            }
        )

        Set-WPFStoredItem -Storage $Storage -Name 'Pokemon' -Value $Value
        $Actual = @(Get-WPFStoredItem -Storage $Storage -Name 'Pokemon')

        $Actual.Count | Should -Be 1
        $Actual[0].Name | Should -Be 'Bulbasaur'
        $Actual[0].Id | Should -Be 1
        Join-Path $Storage.RootPath 'Pokemon.json' | Should -Exist
    }

    It 'replaces an existing item' {
        Set-WPFStoredItem -Storage $Storage -Name 'Pokemon' -Value 'Bulbasaur'
        Set-WPFStoredItem -Storage $Storage -Name 'Pokemon' -Value 'Ivysaur'

        Get-WPFStoredItem -Storage $Storage -Name 'Pokemon' | Should -Be 'Ivysaur'
    }

    It 'returns no output for a missing item' {
        Get-WPFStoredItem -Storage $Storage -Name 'Missing' | Should -BeNullOrEmpty
    }

    It 'removes an existing item' {
        Set-WPFStoredItem -Storage $Storage -Name 'Pokemon' -Value 'Bulbasaur'

        Remove-WPFStoredItem -Storage $Storage -Name 'Pokemon'

        Get-WPFStoredItem -Storage $Storage -Name 'Pokemon' | Should -BeNullOrEmpty
    }

    It 'removes a CLIXML item' {
        Set-WPFStoredItem -Storage $Storage -Name 'Pokemon' -Value 'Bulbasaur' -Format CliXml

        Remove-WPFStoredItem -Storage $Storage -Name 'Pokemon' -Format CliXml

        Get-WPFStoredItem -Storage $Storage -Name 'Pokemon' -Format CliXml | Should -BeNullOrEmpty
    }

    It 'rejects item names that can escape the storage directory' {
        {
            Set-WPFStoredItem -Storage $Storage -Name '..\Pokemon' -Value 'Bulbasaur'
        } | Should -Throw '*not a valid file name*'
    }

    It 'reports corrupt stored data instead of treating it as missing' {
        Set-Content -LiteralPath (Join-Path $Storage.RootPath 'Pokemon.json') -Value 'not json'

        {
            Get-WPFStoredItem -Storage $Storage -Name 'Pokemon'
        } | Should -Throw
    }

    It 'rejects a concurrent write to the same item' {
        $LockPath = Join-Path $Storage.RootPath 'Pokemon.json.lock'
        $LockStream = [System.IO.File]::Open(
            $LockPath,
            [System.IO.FileMode]::OpenOrCreate,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )

        try {
            {
                Set-WPFStoredItem -Storage $Storage -Name 'Pokemon' -Value 'Bulbasaur' -ErrorAction Stop
            } | Should -Throw '*currently being written*'
        } finally {
            $LockStream.Dispose()
        }
    }
}
