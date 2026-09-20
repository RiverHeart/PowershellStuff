BeforeAll {
    Import-Module -Name "$PSScriptRoot/../../Nitpick.psd1" -Force
}

AfterAll {
    Remove-Module -Name Nitpick -Force -ErrorAction SilentlyContinue
}

Describe 'Resolve-Version' {
    It 'adds a minor component to a major-only version' {
        $Result = InModuleScope Nitpick {
            Resolve-Version -Version '2'
        }

        $Result | Should -BeOfType [version]
        $Result | Should -Be ([version] '2.0')
    }

    It 'preserves a complete version' {
        $Result = InModuleScope Nitpick {
            Resolve-Version -Version '1.2.3.4'
        }

        $Result | Should -Be ([version] '1.2.3.4')
    }

    It 'rejects an invalid version' {
        {
            InModuleScope Nitpick {
                Resolve-Version -Version '1.2-preview' -ErrorAction Stop
            }
        } | Should -Throw '*Expected format*'
    }
}
