BeforeAll {
    Import-Module "$PSScriptRoot\..\..\..\Nitpick.psd1" -Force

    function ConvertTo-TestConfiguration {
        param([string] $Text, [string] $BaseDirectory)

        $Data = ConvertFrom-PowerShellData -String $Text -ErrorAction Stop
        $Params = @{ Data = $Data }
        if ($BaseDirectory) { $Params.BaseDirectory = $BaseDirectory }
        New-NitpickConfiguration @Params
    }
}

AfterAll {
    Remove-Module Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'New-NitpickConfiguration' {
    It 'normalizes supported release <Release>' -ForEach @(
        '5.1',
        '6.0', '6.1', '6.2',
        '7.0', '7.1', '7.2', '7.3', '7.4', '7.5', '7.6' |
        ForEach-Object { @{ Release = $_ } }
    ) {
        $Policy = New-NitpickConfiguration -Compatibility @{ PowerShell = @{ MinimumVersion = $Release } }

        $Policy.Compatibility.PowerShell.MinimumVersion | Should -BeOfType ([version])
        $Policy.Compatibility.PowerShell.MinimumVersion.ToString() | Should -BeExactly $Release
        $Policy.Compatibility.PowerShell.MinimumVersion.Build | Should -Be -1
    }

    It 'rejects invalid minimum <Expression>' -ForEach @(
        "'5'", "'5.0'", "'7'", "'7.4.0'", "'7.4-preview.1'", "' 7.4'", "'7.4 '",
        '7.4', '7', "'99.0'", "'6.3'", "'7.7'", "''", '$null', '$false', '@()', '@{}' |
            ForEach-Object { @{ Expression = $_ } }
    ) {
        { ConvertTo-TestConfiguration "@{ Compatibility = @{ PowerShell = @{ MinimumVersion = $Expression } } }" } |
            Should -Throw -ErrorId 'NitpickInvalidConfiguration*'
    }

    It 'normalizes empty configuration <Text>' -ForEach @(
        '@{}', '@{ Compatibility = @{} }', '@{ Compatibility = @{ PowerShell = @{} } }',
        '@{ Rules = @{} }', '@{ Modules = @() }' |
            ForEach-Object { @{ Text = $_ } }
    ) {
        $Policy = ConvertTo-TestConfiguration $Text

        $Policy | Should -BeOfType ([hashtable])
        $Policy.Count | Should -Be 0
    }

    It 'returns empty configuration when no sections are passed' {
        $Policy = New-NitpickConfiguration

        $Policy | Should -BeOfType ([hashtable])
        $Policy.Count | Should -Be 0
    }

    It 'builds the same configuration from sections, data, or a splatted dictionary' {
        $Data = @{
            Compatibility = @{ PowerShell = @{ MinimumVersion = '5.1' } }
            Modules = 'WPF'
            Rules = @{ 'Nitpick/AvoidLongLines' = @{ MaximumLength = 100 } }
        }

        $FromSections = New-NitpickConfiguration `
            -Compatibility $Data.Compatibility `
            -Modules $Data.Modules `
            -Rules $Data.Rules

        $FromData = New-NitpickConfiguration -Data $Data
        $FromSplat = New-NitpickConfiguration @Data

        foreach ($Configuration in $FromSections, $FromData, $FromSplat) {
            $Configuration.Compatibility.PowerShell.MinimumVersion | Should -Be ([version] '5.1')
            $Configuration.Modules | Should -Be @('WPF')
            $Configuration.Rules['Nitpick/AvoidLongLines'].MaximumLength | Should -Be 100
        }
    }

    It 'rejects a section passed explicitly as null' {
        { New-NitpickConfiguration -Modules $null } |
            Should -Throw -ErrorId 'NitpickInvalidConfiguration*'
    }

    It 'rejects malformed or unknown schema <Text>' -ForEach @(
        '@{ Compatibility = $null }',
        '@{ Compatibility = 1 }',
        '@{ Compatibility = @() }',
        '@{ Compatibility = @{ PowerShell = $null } }',
        '@{ Compatibility = @{ PowerShell = "5.1" } }',
        '@{ Compatibility = @{ PowerShell = @() } }',
        '@{ Keys = @() }',
        '@{ Compatibility = @{ Keys = @() } }',
        '@{ Compatibility = @{ PowerShell = @{ Keys = @() } } }',
        '@{ Caller = "spoofed" }',
        '@{ Compatibility = @{ Typo = @{} } }',
        '@{ Compatibility = @{ PowerShell = @{ MinVersion = "5.1" } } }',
        '@{ Compatibility = @{ PowerShell = @{}; Typo = 1 } }',
        '@{ Rules = $null }',
        '@{ Rules = @{ UnknownRule = @{} } }',
        '@{ Rules = @{ "Nitpick/AvoidLongLines" = 1 } }',
        '@{ 1 = @{} }',
        '@{ Modules = $null }',
        '@{ Modules = "" }',
        '@{ Modules = "   " }',
        '@{ Modules = 1 }',
        '@{ Modules = @{} }',
        '@{ Modules = @("WPF", 2) }',
        '@{ Modules = @("WPF", @("Nested")) }',
        '@{ Modules = "Nitpick*" }' |
            ForEach-Object { @{ Text = $_ } }
    ) {
        { ConvertTo-TestConfiguration $Text } |
            Should -Throw -ErrorId 'NitpickInvalidConfiguration*'
    }

    It 'explains that wildcard module names are not supported' {
        { New-NitpickConfiguration -Modules 'Nitpick*' } |
            Should -Throw '*must be an exact module name, not a wildcard pattern*'
    }

    It 'returns a single module name as a one-element array' {
        $Configuration = New-NitpickConfiguration -Modules 'WPF'

        $Configuration.Modules | Should -BeOfType ([string])
        , $Configuration.Modules | Should -BeOfType ([string[]])
        $Configuration.Modules | Should -Be @('WPF')
    }

    It 'resolves relative module paths from the base directory, not the caller location' {
        $BaseDirectory = Join-Path $TestDrive 'project\config'
        $Elsewhere = New-Item -Path (Join-Path $TestDrive 'elsewhere') -ItemType Directory
        # A same-named directory at the caller's location must not turn a name into a path.
        $null = New-Item -Path (Join-Path $Elsewhere.FullName 'WPF') -ItemType Directory
        $RootedPath = Join-Path $TestDrive 'Rooted\Rooted.psd1'
        $Modules = @(
            'WPF'
            '.\rules\Custom.psd1'
            '..\shared\Shared.psm1'
            'Local.psm1'
            $RootedPath
            'FileSystem::C:\Provider\Rules'
        )

        Push-Location -LiteralPath $Elsewhere.FullName
        try {
            $Resolved = (New-NitpickConfiguration -Modules $Modules -BaseDirectory $BaseDirectory).Modules
        } finally {
            Pop-Location
        }

        $Resolved | Should -Be @(
            'WPF'
            (Join-Path $BaseDirectory 'rules\Custom.psd1')
            (Join-Path $TestDrive 'project\shared\Shared.psm1')
            (Join-Path $BaseDirectory 'Local.psm1')
            $RootedPath
            'FileSystem::C:\Provider\Rules'
        )
    }

    It 'rejects a relative module path <Entry> without a base directory' -ForEach @(
        '.\rules\Custom.psd1', 'Local.psm1' | ForEach-Object { @{ Entry = $_ } }
    ) {
        { New-NitpickConfiguration -Modules $Entry } |
            Should -Throw '*relative path; pass -BaseDirectory or use an absolute path*'
    }

    It 'accepts module names and absolute paths without a base directory' {
        $RootedPath = Join-Path $TestDrive 'Rooted.psd1'

        $Configuration = New-NitpickConfiguration -Modules 'WPF', $RootedPath, 'FileSystem::C:\Rules'

        $Configuration.Modules | Should -Be @('WPF', $RootedPath, 'FileSystem::C:\Rules')
    }

    It 'rejects module-manifest-like data with a specific message <Key>' -ForEach @(
        'ModuleVersion', 'RootModule', 'GUID' | ForEach-Object { @{ Key = $_ } }
    ) {
        { New-NitpickConfiguration -Data @{ $Key = 'value' } } |
            Should -Throw '*looks like a PowerShell module manifest*'
    }

    It 'accepts its own output and returns the same configuration' {
        $First = New-NitpickConfiguration `
            -Compatibility @{ PowerShell = @{ MinimumVersion = '5.1' } } `
            -Modules 'WPF', '.\rules\Custom.psd1' `
            -Rules @{ 'Nitpick/AvoidLongLines' = @{ MaximumLength = 100 } } `
            -BaseDirectory $TestDrive

        $Second = New-NitpickConfiguration -Data $First

        $Second.Compatibility.PowerShell.MinimumVersion | Should -Be ([version] '5.1')
        $Second.Modules | Should -Be $First.Modules
        $Second.Rules['Nitpick/AvoidLongLines'].MaximumLength | Should -Be 100
    }

    It 'rejects a System.Version minimum with more than two components' {
        { New-NitpickConfiguration -Compatibility @{ PowerShell = @{ MinimumVersion = [version] '5.1.0' } } } |
            Should -Throw -ErrorId 'NitpickInvalidConfiguration*'
    }

    It 'accepts case-insensitive keys' {
        $Policy = ConvertTo-TestConfiguration '@{ compatibility = @{ powershell = @{ minimumversion = "5.1" } } }'

        $Policy.Compatibility.PowerShell.MinimumVersion | Should -Be ([version] '5.1')
    }
}
