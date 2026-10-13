BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'New-NitpickModule' {
    It 'derives IsLoaded from LoadedInstance rather than accepting it separately' {
        $Instance = Get-Module Nitpick
        $Result = InModuleScope Nitpick -Parameters @{ Instance = $Instance } {
            param ($Instance)
            $ModuleParams = @{
                Name = $Instance.Name
                Version = $Instance.Version
                Path = $Instance.Path
                ManifestPath = $Instance.Path
                LoadedInstance = $Instance
            }
            New-NitpickModule @ModuleParams
        }

        $Result.PSTypeNames | Should -Contain 'Nitpick.Module'
        $Result.IsLoaded | Should -BeTrue
        [object]::ReferenceEquals($Result.LoadedInstance, $Instance) | Should -BeTrue
    }

    It 'defaults IsLoaded to false when no loaded instance is supplied' {
        $Result = InModuleScope Nitpick {
            New-NitpickModule -Name 'NotLoadedModule' -Path 'C:\NotLoadedModule\NotLoadedModule.psd1'
        }

        $Result.IsLoaded | Should -BeFalse
        $Result.LoadedInstance | Should -BeNullOrEmpty
    }
}
