BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Resolve-Module' {
    It 'resolves a loaded module at the required version' {
        $Result = InModuleScope Nitpick {
            Resolve-Module -Module Nitpick -RequiredVersion '0.0.1'
        }

        $Result | Should -BeOfType [System.Management.Automation.PSModuleInfo]
        $Result.Name | Should -Be 'Nitpick'
        $Result.Version | Should -Be ([version] '0.0.1')
        $Result.IsLoaded | Should -BeTrue
    }

    It 'resolves an available module by path' {
        $ModuleDirectory = New-Item -Path "$TestDrive/TestDriveModule" -ItemType Directory
        $ModulePath = Join-Path -Path $ModuleDirectory.FullName -ChildPath 'TestDriveModule.psd1'
        New-ModuleManifest -Path $ModulePath -RootModule 'TestDriveModule.psm1' -ModuleVersion '1.2.3'
        Set-Content -Path "$($ModuleDirectory.FullName)/TestDriveModule.psm1" -Value ''

        $OriginalModulePath = $env:PSModulePath
        try {
            $env:PSModulePath = "$TestDrive$([IO.Path]::PathSeparator)$OriginalModulePath"
            $Result = InModuleScope Nitpick -Parameters @{ ModulePath = $ModulePath } {
                Resolve-Module -Module $ModulePath
            }
        } finally {
            $env:PSModulePath = $OriginalModulePath
        }

        $Result | Should -BeOfType [System.Management.Automation.PSModuleInfo]
        $Result.Name | Should -Be 'TestDriveModule'
        $Result.ModuleBase | Should -Be $ModuleDirectory.FullName
        $Result.IsLoaded | Should -BeFalse
    }

    It 'rejects a module that cannot be found' {
        {
            InModuleScope Nitpick {
                Resolve-Module -Module 'Nitpick.Module.That.Does.Not.Exist' -ErrorAction Stop
            }
        } | Should -Throw '*was not found*'
    }
}
