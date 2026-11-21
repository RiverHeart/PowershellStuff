BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../../Nitpick.psd1" -Force

    function New-ResolverTestModule {
        param(
            [Parameter(Mandatory)]
            [string] $Name,

            [Parameter(Mandatory)]
            [string] $Root,

            [string] $Version = '1.0.0'
        )

        $Directory = New-Item -Path (Join-Path $Root $Name) -ItemType Directory -Force
        $ScriptModulePath = Join-Path $Directory.FullName ($Name + '.psm1')
        Set-Content -LiteralPath $ScriptModulePath -Value "function Test-$Name { param(`$ScriptBlockAst) }"
        $ManifestPath = Join-Path $Directory.FullName ($Name + '.psd1')
        New-ModuleManifest -Path $ManifestPath -RootModule ($Name + '.psm1') -ModuleVersion $Version

        [pscustomobject] @{
            Name = $Name
            Directory = $Directory.FullName
            ManifestPath = $ManifestPath
            ScriptModulePath = $ScriptModulePath
        }
    }
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Resolve-NitpickModuleSource' {
    BeforeEach {
        $ResolverRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -Path $ResolverRoot -ItemType Directory
    }

    AfterEach {
        InModuleScope Nitpick -Parameters @{ Root = $ResolverRoot } {
            param($Root)
            Get-Module -All |
                Where-Object { $_.ModuleBase -like "$Root*" } |
                Remove-Module -Force -ErrorAction SilentlyContinue
        }
    }

    It 'reuses the single matching loaded instance by name' {
        $Result = InModuleScope Nitpick {
            Resolve-NitpickModuleSource -Module Nitpick
        }

        $Result.Name | Should -Be Nitpick
        $Result.IsLoaded | Should -BeTrue
        [object]::ReferenceEquals($Result.LoadedInstance, (Get-Module Nitpick)) | Should -BeTrue
    }

    It 'rejects multiple loaded instances of the same name' {
        $First = New-ResolverTestModule `
            -Name DuplicateContractModule `
            -Root (Join-Path $ResolverRoot 'First') `
            -Version '1.0.0'

        $Second = New-ResolverTestModule `
            -Name DuplicateContractModule `
            -Root (Join-Path $ResolverRoot 'Second') `
            -Version '2.0.0'

        Import-Module -Name $First.ManifestPath -ErrorAction Stop
        Import-Module -Name $Second.ManifestPath -ErrorAction Stop

        {
            InModuleScope Nitpick {
                Resolve-NitpickModuleSource -Module DuplicateContractModule -ErrorAction Stop
            }
        } | Should -Throw '*ambiguous*'
    }

    It 'selects the highest available version among non-loaded candidates' {
        $RootA = Join-Path $ResolverRoot 'RootA'
        $RootB = Join-Path $ResolverRoot 'RootB'
        New-ResolverTestModule -Name HighestVersionModule -Root $RootA -Version '1.0.0' | Out-Null
        $High = New-ResolverTestModule -Name HighestVersionModule -Root $RootB -Version '2.0.0'

        $OriginalModulePath = $env:PSModulePath
        try {
            $env:PSModulePath = "$RootA$([IO.Path]::PathSeparator)$RootB$([IO.Path]::PathSeparator)$OriginalModulePath"
            $Result = InModuleScope Nitpick {
                Resolve-NitpickModuleSource -Module HighestVersionModule
            }
        } finally {
            $env:PSModulePath = $OriginalModulePath
        }

        $Result.Version | Should -Be ([version] '2.0.0')
        $Result.Path | Should -Be $High.ManifestPath
        $Result.IsLoaded | Should -BeFalse
    }

    It 'rejects equal-version ambiguity among distinct available sources' {
        $RootA = Join-Path $ResolverRoot 'RootA'
        $RootB = Join-Path $ResolverRoot 'RootB'
        New-ResolverTestModule -Name AmbiguousVersionModule -Root $RootA -Version '1.0.0' | Out-Null
        New-ResolverTestModule -Name AmbiguousVersionModule -Root $RootB -Version '1.0.0' | Out-Null

        $OriginalModulePath = $env:PSModulePath
        try {
            $env:PSModulePath = "$RootA$([IO.Path]::PathSeparator)$RootB$([IO.Path]::PathSeparator)$OriginalModulePath"
            {
                InModuleScope Nitpick {
                    Resolve-NitpickModuleSource -Module AmbiguousVersionModule -ErrorAction Stop
                }
            } | Should -Throw '*ambiguous*'
        } finally {
            $env:PSModulePath = $OriginalModulePath
        }
    }

    It 'rejects a module name that does not exist' {
        {
            InModuleScope Nitpick {
                Resolve-NitpickModuleSource -Module 'Nitpick.Module.That.Does.Not.Exist' -ErrorAction Stop
            }
        } | Should -Throw '*was not found*'
    }

    It 'rejects a wildcard module name without attempting resolution' {
        {
            InModuleScope Nitpick {
                Resolve-NitpickModuleSource -Module 'Nit*' -ErrorAction Stop
            }
        } | Should -Throw '*wildcard*'
    }

    It 'resolves a relative manifest path from the current location' {
        $Package = New-ResolverTestModule -Name RelativePathModule -Root $ResolverRoot
        Push-Location -LiteralPath $ResolverRoot
        try {
            $Result = InModuleScope Nitpick -Parameters @{ Name = $Package.Name } {
                param($Name)
                Resolve-NitpickModuleSource -Module ".\$Name\$Name.psd1"
            }
        } finally {
            Pop-Location
        }

        $Result.Name | Should -Be $Package.Name
        $Result.Path | Should -Be $Package.ManifestPath
        $Result.ManifestPath | Should -Be $Package.ManifestPath
        $Result.IsLoaded | Should -BeFalse
    }

    It 'resolves an absolute path to a script module and finds its sibling manifest' {
        $Package = New-ResolverTestModule -Name AbsolutePathModule -Root $ResolverRoot
        $Result = InModuleScope Nitpick -Parameters @{ Path = $Package.ScriptModulePath } {
            param($Path)
            Resolve-NitpickModuleSource -Module $Path
        }

        $Result.Path | Should -Be $Package.ScriptModulePath
        $Result.ManifestPath | Should -Be $Package.ManifestPath
        $Result.Name | Should -Be $Package.Name
    }

    It 'resolves a bare manifest filename relative to the current location' {
        $Package = New-ResolverTestModule -Name BareFilenameModule -Root $ResolverRoot
        Push-Location -LiteralPath $Package.Directory
        try {
            $Result = InModuleScope Nitpick -Parameters @{ Name = $Package.Name } {
                param($Name)
                Resolve-NitpickModuleSource -Module "$Name.psd1"
            }
        } finally {
            Pop-Location
        }

        $Result.Path | Should -Be $Package.ManifestPath
    }

    It 'resolves a module directory using entrypoint conventions' {
        $Package = New-ResolverTestModule -Name DirectoryEntrypointModule -Root $ResolverRoot
        $Result = InModuleScope Nitpick -Parameters @{ Dir = $Package.Directory } {
            param($Dir)
            Resolve-NitpickModuleSource -Module $Dir
        }

        $Result.Path | Should -Be $Package.ManifestPath
        $Result.Name | Should -Be $Package.Name
    }

    It 'accepts a binary module extension without validating assembly contents' {
        $DllPath = Join-Path $ResolverRoot 'FakeBinary.dll'
        [System.IO.File]::WriteAllBytes($DllPath, [byte[]] (1, 2, 3, 4))

        $Result = InModuleScope Nitpick -Parameters @{ Path = $DllPath } {
            param($Path)
            Resolve-NitpickModuleSource -Module $Path
        }

        $Result.Path | Should -Be $DllPath
        $Result.Name | Should -Be 'FakeBinary'
        $Result.IsLoaded | Should -BeFalse
    }

    It 'rejects an unsupported file extension' {
        $InvalidPath = Join-Path $ResolverRoot 'LooseScript.ps1'
        Set-Content -LiteralPath $InvalidPath -Value '# not a module'

        {
            InModuleScope Nitpick -Parameters @{ Path = $InvalidPath } {
                param($Path)
                Resolve-NitpickModuleSource -Module $Path -ErrorAction Stop
            }
        } | Should -Throw '*must be a module directory*'
    }

    It 'treats a path-shaped missing value as an explicit error without falling back to name resolution' {
        $Decoy = New-ResolverTestModule -Name Ghost -Root $ResolverRoot
        Import-Module -Name $Decoy.ManifestPath -ErrorAction Stop

        {
            InModuleScope Nitpick {
                Resolve-NitpickModuleSource -Module '.\DoesNotExist\Ghost.psd1' -ErrorAction Stop
            }
        } | Should -Throw '*was not found*'
    }

    It 'pins a literal path even when a same-named module is loaded from elsewhere' {
        $First = New-ResolverTestModule `
            -Name PinnedPathModule `
            -Root (Join-Path $ResolverRoot 'First') `
            -Version '1.0.0'

        $Second = New-ResolverTestModule `
            -Name PinnedPathModule `
            -Root (Join-Path $ResolverRoot 'Second') `
            -Version '2.0.0'

        Import-Module -Name $First.ManifestPath -ErrorAction Stop

        $Result = InModuleScope Nitpick -Parameters @{ Path = $Second.ManifestPath } {
            param($Path)
            Resolve-NitpickModuleSource -Module $Path
        }

        $Result.Path | Should -Be $Second.ManifestPath
        $Result.IsLoaded | Should -BeFalse
        $Result.Version | Should -Be ([version] '2.0.0')
    }

    It 'rejects a provider-qualified path outside the FileSystem provider' {
        {
            InModuleScope Nitpick {
                Resolve-NitpickModuleSource -Module 'Env:\PSModulePath' -ErrorAction Stop
            }
        } | Should -Throw '*FileSystem*'
    }

    It 'does not import or initialize modules while resolving' {
        $Package = New-ResolverTestModule -Name NoImportModule -Root $ResolverRoot
        Mock Import-Module -ModuleName Nitpick { throw 'Resolution must not import modules.' }

        {
            InModuleScope Nitpick -Parameters @{ Path = $Package.ManifestPath } {
                param($Path)
                Resolve-NitpickModuleSource -Module $Path
                Resolve-NitpickModuleSource -Module NoImportModule -ErrorAction SilentlyContinue
            }
        } | Should -Not -Throw

        Should -Invoke Import-Module -ModuleName Nitpick -Times 0
    }
}
