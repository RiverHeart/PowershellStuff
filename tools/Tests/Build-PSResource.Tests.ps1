[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', ''
)]
param ()

BeforeAll {
    $BuildScript = Join-Path -Path $PSScriptRoot -ChildPath '../Build-PSResource.ps1'
    $ShouldContinueScript = Join-Path -Path $PSScriptRoot -ChildPath '../Private/Should-Continue.ps1'

    <#
    .SYNOPSIS
        Captures the staged module file list for package builder tests.

    .PARAMETER Path
        Path to the staged module.

    .PARAMETER DestinationPath
        Path in which to write the captured file list.

    .PARAMETER PassThru
        Accepted for compatibility with Compress-PSResource; no value is returned.

    .EXAMPLE
        Compress-PSResource -Path ./staging/Example -DestinationPath ./packages -PassThru
    #>
    function Compress-PSResource {
        param (
            [string] $Path,
            [string] $DestinationPath,
            [switch] $PassThru
        )

        @(
            Get-ChildItem -LiteralPath $Path -File -Recurse |
                ForEach-Object {
                    $_.FullName.Substring($Path.Length).TrimStart('\', '/').Replace('\', '/')
                }
        ) |
        ConvertTo-Json |
        Set-Content -LiteralPath (Join-Path -Path $DestinationPath -ChildPath 'packaged-files.json')
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

Describe 'Build-PSResource Git ignore filtering' {
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
            '    Package = @{'
            '        Include = @('
            "            'PackageProject.psd1'"
            "            'PackageProject.psm1'"
            "            'Public'"
            '        )'
            '    }'
            '}'
        ) | Set-Content -LiteralPath (Join-Path -Path $ProjectRoot -ChildPath 'project.psd1')

    }

    AfterEach {
        Remove-Item `
            -LiteralPath (Join-Path -Path $Destination -ChildPath 'packaged-files.json') `
            -Force `
            -ErrorAction SilentlyContinue
    }

    It 'omits ignored files from explicitly included directories' {
        @(
            '*.local.ps1'
            'Generated.ps1'
        ) | Set-Content -LiteralPath (Join-Path -Path $PublicRoot -ChildPath '.gitignore')
        & git -C $TestRoot init --quiet
        & git -C $TestRoot add --force PackageProject/Public/Secret.local.ps1

        & $BuildScript `
            -ProjectPath (Join-Path -Path $ProjectRoot -ChildPath 'project.psd1') `
            -DestinationPath $Destination

        $PackagedFiles = Get-Content -LiteralPath (Join-Path -Path $Destination -ChildPath 'packaged-files.json') |
            ConvertFrom-Json
        $PackagedFiles | Should -Contain 'Public/Keep.ps1'
        $PackagedFiles | Should -Contain 'Public/Generated.keep.ps1'
        $PackagedFiles | Should -Not -Contain 'Public/Secret.local.ps1'
        $PackagedFiles | Should -Not -Contain 'Public/Generated.ps1'
        $PackagedFiles | Should -Not -Contain 'Public/.gitignore'
    }

    It 'honors negated patterns in Git ignore rules' {
        @(
            'Generated*.ps1'
            '!Generated.keep.ps1'
        ) | Set-Content -LiteralPath (Join-Path -Path $PublicRoot -ChildPath '.gitignore')
        & git -C $TestRoot init --quiet

        & $BuildScript `
            -ProjectPath (Join-Path -Path $ProjectRoot -ChildPath 'project.psd1') `
            -DestinationPath $Destination

        $PackagedFiles = Get-Content -LiteralPath (Join-Path -Path $Destination -ChildPath 'packaged-files.json') |
            ConvertFrom-Json
        $PackagedFiles | Should -Contain 'Public/Generated.keep.ps1'
        $PackagedFiles | Should -Not -Contain 'Public/Generated.ps1'
    }

    It 'keeps all included files outside a Git worktree' {
        & $BuildScript `
            -ProjectPath (Join-Path -Path $ProjectRoot -ChildPath 'project.psd1') `
            -DestinationPath $Destination

        $PackagedFiles = Get-Content -LiteralPath (Join-Path -Path $Destination -ChildPath 'packaged-files.json') |
            ConvertFrom-Json
        $PackagedFiles | Should -Contain 'Public/Secret.local.ps1'
        $PackagedFiles | Should -Contain 'Public/Generated.ps1'
    }

    It 'continues without Git ignore filtering only when explicitly forced' {
        '*.local.ps1' | Set-Content -LiteralPath (Join-Path -Path $PublicRoot -ChildPath '.gitignore')
        Mock Get-Command -ParameterFilter { $Name -eq 'git' } -MockWith { Write-Output $null }

        & $BuildScript `
            -ProjectPath (Join-Path -Path $ProjectRoot -ChildPath 'project.psd1') `
            -DestinationPath $Destination `
            -Force

        $PackagedFiles = Get-Content -LiteralPath (Join-Path -Path $Destination -ChildPath 'packaged-files.json') |
            ConvertFrom-Json
        $PackagedFiles | Should -Contain 'Public/Secret.local.ps1'
    }
}
