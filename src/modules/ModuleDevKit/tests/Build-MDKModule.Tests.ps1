[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', ''
)]
param ()

BeforeAll {
    $ModuleManifest = Join-Path -Path $PSScriptRoot -ChildPath '../ModuleDevKit.psd1'
    $ShouldContinueScript = Join-Path -Path $PSScriptRoot -ChildPath '../src/Private/Should-Continue.ps1'
    Import-Module $ModuleManifest -Force -ErrorAction Stop

    function Get-PackagedFile {
        param(
            [Parameter(Mandatory)]
            [string] $DestinationPath
        )

        $PackagePath = Get-ChildItem -LiteralPath $DestinationPath -Filter '*.nupkg' -File |
            Select-Object -First 1
        $Archive = [System.IO.Compression.ZipFile]::OpenRead($PackagePath.FullName)
        try {
            Write-Output -InputObject @(
                $Archive.Entries |
                    Where-Object { $_.FullName -notlike '*/' } |
                    Select-Object -ExpandProperty FullName |
                    ForEach-Object { $_.Replace('\', '/') }
            )
        } finally {
            $Archive.Dispose()
        }
    }
}

Describe 'Should-Continue prompt behavior' {
    It 'requests confirmation through a host' {
        $Runspace = [powershell]::Create()
        try {
            [void] $Runspace.AddScript({
                param ($Path)
                . $Path
                Should-Continue -Message 'Continue the operation?' -Caption 'Confirmation required'
            }).AddArgument($ShouldContinueScript)

            $Result = @($Runspace.Invoke())

            @($Result | Where-Object { $null -ne $_ }) | Should -HaveCount 0
            $Runspace.Streams.Error | Should -HaveCount 1
            $Runspace.Streams.Error[0].FullyQualifiedErrorId | Should -Be 'HostException'
            $Runspace.Streams.Error[0].Exception.Message | Should -Match 'ShouldContinue'
        } finally {
            $Runspace.Dispose()
        }
    }

    It 'can bypass confirmation with Force' {
        $Runspace = [powershell]::Create()
        try {
            [void] $Runspace.AddScript({
                param ($Path)
                . $Path
                Should-Continue `
                    -Message 'Continue the operation?' `
                    -Caption 'Confirmation required' `
                    -Force
            }).AddArgument($ShouldContinueScript)

            $Result = @($Runspace.Invoke())

            $Runspace.Streams.Error | Should -HaveCount 0
            $Result | Should -HaveCount 1
            $Result[0] | Should -BeTrue
        } finally {
            $Runspace.Dispose()
        }
    }
}

Describe 'Build-MDKModule packaging' {
    BeforeEach {
        $TestRoot = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString('N'))
        $ProjectRoot = Join-Path -Path $TestRoot -ChildPath 'PackageProject'
        $PublicRoot = Join-Path -Path $ProjectRoot -ChildPath 'Public'
        $Destination = Join-Path -Path $TestRoot -ChildPath 'packages'
        New-Item -Path $PublicRoot -ItemType Directory -Force | Out-Null

        @(
            '@{'
            "    RootModule = 'PackageProject.psm1'"
            "    ModuleVersion = '1.0.0'"
            "    GUID = '8ad9cb8c-ca35-4c4b-bd87-5efc1f0afc9f'"
            "    Author = 'Test'"
            "    Description = 'Package test fixture.'"
            '    FileList = @('
            "        'PackageProject.psd1'"
            "        'PackageProject.psm1'"
            "        'Public/Keep.ps1'"
            "        'Public/Secret.local.ps1'"
            "        'Public/Generated.ps1'"
            "        'Public/Generated.keep.ps1'"
            '    )'
            '}'
        ) | Set-Content -LiteralPath (Join-Path -Path $ProjectRoot -ChildPath 'PackageProject.psd1')
        '' | Set-Content -LiteralPath (Join-Path -Path $ProjectRoot -ChildPath 'PackageProject.psm1')
        'keep' | Set-Content -LiteralPath (Join-Path -Path $PublicRoot -ChildPath 'Keep.ps1')
        'omit' | Set-Content -LiteralPath (Join-Path -Path $PublicRoot -ChildPath 'Secret.local.ps1')
        'omit' | Set-Content -LiteralPath (Join-Path -Path $PublicRoot -ChildPath 'Generated.ps1')
        'keep' | Set-Content -LiteralPath (Join-Path -Path $PublicRoot -ChildPath 'Generated.keep.ps1')

        @(
            '@{'
            "    Name = 'PackageProject'"
            '}'
        ) | Set-Content -LiteralPath (Join-Path -Path $ProjectRoot -ChildPath 'project.psd1')

    }

    It 'omits ignored files from explicitly included directories' {
        @(
            '*.local.ps1'
            'Generated.ps1'
        ) | Set-Content -LiteralPath (Join-Path -Path $PublicRoot -ChildPath '.gitignore')
        & git -C $TestRoot init --quiet
        & git -C $TestRoot add --force PackageProject/Public/Secret.local.ps1

        Build-MDKModule `
            -ProjectPath (Join-Path -Path $ProjectRoot -ChildPath 'project.psd1') `
            -DestinationPath $Destination

        $PackagedFiles = Get-PackagedFile -DestinationPath $Destination
        $PackagedFiles | Should -Contain 'Public/Keep.ps1'
        $PackagedFiles | Should -Contain 'Public/Generated.keep.ps1'
        $PackagedFiles | Should -Not -Contain 'Public/Secret.local.ps1'
        $PackagedFiles | Should -Not -Contain 'Public/Generated.ps1'
        $PackagedFiles | Should -Not -Contain 'Public/.gitignore'
        $LASTEXITCODE | Should -Be 0
    }

    It 'honors negated patterns in Git ignore rules' {
        @(
            'Generated*.ps1'
            '!Generated.keep.ps1'
        ) | Set-Content -LiteralPath (Join-Path -Path $PublicRoot -ChildPath '.gitignore')
        & git -C $TestRoot init --quiet

        Build-MDKModule `
            -ProjectPath (Join-Path -Path $ProjectRoot -ChildPath 'project.psd1') `
            -DestinationPath $Destination

        $PackagedFiles = Get-PackagedFile -DestinationPath $Destination
        $PackagedFiles | Should -Contain 'Public/Generated.keep.ps1'
        $PackagedFiles | Should -Not -Contain 'Public/Generated.ps1'
    }

    It 'keeps all included files outside a Git worktree' {
        Build-MDKModule `
            -ProjectPath (Join-Path -Path $ProjectRoot -ChildPath 'project.psd1') `
            -DestinationPath $Destination

        $PackagedFiles = Get-PackagedFile -DestinationPath $Destination
        $PackagedFiles | Should -Contain 'Public/Secret.local.ps1'
        $PackagedFiles | Should -Contain 'Public/Generated.ps1'
    }

    It 'does not require Package metadata in project.psd1' {
        Build-MDKModule `
            -ProjectPath (Join-Path -Path $ProjectRoot -ChildPath 'project.psd1') `
            -DestinationPath $Destination

        $PackagedFiles = Get-PackagedFile -DestinationPath $Destination
        $PackagedFiles | Should -Contain 'PackageProject.psd1'
        $PackagedFiles | Should -Contain 'Public/Keep.ps1'
    }

    It 'packages only files listed in the module manifest' {
        'unlisted' | Set-Content -LiteralPath (Join-Path -Path $PublicRoot -ChildPath 'Unlisted.ps1')

        Build-MDKModule `
            -ProjectPath (Join-Path -Path $ProjectRoot -ChildPath 'project.psd1') `
            -DestinationPath $Destination

        $PackagedFiles = Get-PackagedFile -DestinationPath $Destination
        $PackagedFiles | Should -Contain 'Public/Keep.ps1'
        $PackagedFiles | Should -Not -Contain 'Public/Unlisted.ps1'
    }

    It 'requires a FileList in the module manifest' {
        @(
            '@{'
            "    RootModule = 'PackageProject.psm1'"
            "    ModuleVersion = '1.0.0'"
            "    GUID = '8ad9cb8c-ca35-4c4b-bd87-5efc1f0afc9f'"
            "    Author = 'Test'"
            "    Description = 'Package test fixture.'"
            '}'
        ) | Set-Content -LiteralPath (Join-Path -Path $ProjectRoot -ChildPath 'PackageProject.psd1')

        {
            Build-MDKModule `
                -ProjectPath (Join-Path -Path $ProjectRoot -ChildPath 'project.psd1') `
                -DestinationPath $Destination
        } | Should -Throw '*must define a non-empty FileList*'
    }

    It 'rejects wildcard entries in the module manifest FileList' {
        @(
            '@{'
            "    RootModule = 'PackageProject.psm1'"
            "    ModuleVersion = '1.0.0'"
            "    GUID = '8ad9cb8c-ca35-4c4b-bd87-5efc1f0afc9f'"
            "    Author = 'Test'"
            "    Description = 'Package test fixture.'"
            "    FileList = @('PackageProject.psm1', 'Public/*.ps1')"
            '}'
        ) | Set-Content -LiteralPath (Join-Path -Path $ProjectRoot -ChildPath 'PackageProject.psd1')

        {
            Build-MDKModule `
                -ProjectPath (Join-Path -Path $ProjectRoot -ChildPath 'project.psd1') `
                -DestinationPath $Destination
        } | Should -Throw "*FileList path 'Public/*.ps1' must be a literal path*"
    }

    It 'continues without Git ignore filtering only when explicitly forced' {
        '*.local.ps1' | Set-Content -LiteralPath (Join-Path -Path $PublicRoot -ChildPath '.gitignore')
        Mock Get-Command `
            -ModuleName ModuleDevKit `
            -ParameterFilter { $Name -eq 'git' } `
            -MockWith { Write-Output $null }

        Build-MDKModule `
            -ProjectPath (Join-Path -Path $ProjectRoot -ChildPath 'project.psd1') `
            -DestinationPath $Destination `
            -Force

        $PackagedFiles = Get-PackagedFile -DestinationPath $Destination
        $PackagedFiles | Should -Contain 'Public/Secret.local.ps1'
    }
}
