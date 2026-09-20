BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Resolve-Module' {
    It 'resolves a loaded module at the required version' {
        $Result = InModuleScope Nitpick {
            Resolve-Module -Name Nitpick -RequiredVersion '0.0.1'
        }

        $Result | Should -BeOfType [System.Management.Automation.PSModuleInfo]
        $Result.Name | Should -Be 'Nitpick'
        $Result.Version | Should -Be ([version] '0.0.1')
        $Result.IsLoaded | Should -BeTrue
    }

    It 'rejects a module that cannot be found' {
        {
            InModuleScope Nitpick {
                Resolve-Module -Name 'Nitpick.Module.That.Does.Not.Exist' -ErrorAction Stop
            }
        } | Should -Throw '*was not found*'
    }
}
